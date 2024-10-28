#!/bin/sh

# Variables
BACKUP_NAME="pingdirectory-backup"
CRON_JOB_BACKUP_NAME="pingdirectory-periodic-backup"
SCRIPT="/opt/in/backup-ops.sh"
SKIP_RESOURCE_CLEANUP="false"

# Functions

# Function to check determine when a Job is complete
is_job_complete() {
  kubectl get job "${BACKUP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' | grep -qi True
}

# Function to get the number of failed attempts of Job
get_failed_attempts() {
  kubectl get job "${BACKUP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.failed}' 2>/dev/null
}

# Function to get the number of backofflimits/# of retries for Job
get_backoff_limit() {
  kubectl get job "${BACKUP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.backoffLimit}' 2>/dev/null
}

# Function to get actively running Jobs, sorted by the time they were created.
# This will filter out previous Jobs that are retained in the cluster that have failed.
# This is done by jq which filters out status of active and ready.
get_actively_running_manual_jobs() {
  kubectl get jobs -l pd-manual=true -o json -n "${NAMESPACE}" --sort-by=.metadata.creationTimestamp 2>/dev/null | jq -r '.items[] | select(.status.active == 1 and .status.ready == 1) | .metadata.name'
}

# Function to get actively running CronJobs, sorted by the time they were created.
# This will filter out previous CronJobs that are retained in the cluster that have failed.
# This is done by jq which filters out status of active and ready.
get_actively_running_cronjob() {
  kubectl get jobs -o json -n "${NAMESPACE}" --sort-by=.metadata.creationTimestamp 2>/dev/null | jq -r '.items[] | select(.status.active == 1 and .status.ready == 1 and (.metadata.name | contains("pingdirectory-periodic-backup"))) | .metadata.name'
}

# Function to determine if a cronjob is actively running.
is_cronjob_running_now() {
  kubectl get cronjob "${CRON_JOB_BACKUP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.active}' 2>/dev/null
}

# Function to delete Job and its PVC if detected in cluster
cleanup_resources() {
  if [ "${SKIP_RESOURCE_CLEANUP}" = "true" ]; then
    return 0
  fi

  # Remove Job and PVC if found in cluster
  kubectl get job "${BACKUP_NAME}" -n "${NAMESPACE}" > /dev/null 2>&1
  if [ "$?" -eq "0" ]; then
    echo "Deleting job ${BACKUP_NAME}..."
    kubectl delete job "${BACKUP_NAME}" -n "${NAMESPACE}"
  fi
  kubectl get pvc "${BACKUP_NAME}" -n "${NAMESPACE}" > /dev/null 2>&1
  if [ "$?" -eq "0" ]; then
    echo "Deleting PVC ${BACKUP_NAME}..."
    kubectl delete pvc "${BACKUP_NAME}" -n "${NAMESPACE}"
  fi
}

# Function ensures that only one backup Job will run. This will stop CronJob and Jobs from clashing and using
# the same shared PVC.
is_only_one_backup_running() {
    # Determine if Cronjob is actively running. This will be empty if CronJob is not running.
    active_cronjob_running=$(is_cronjob_running_now)
    if [ -n "${active_cronjob_running}" ]; then
        # Entering this condition means there is an active Cronjob running.

        # Determine if Manual Job is also running while Cronjob is running.
        # Manual jobs can be found by filtering on "pd-manual=true" label.
        active_manual_job_name=$(get_actively_running_manual_jobs | head -n 1 | tr -d ' ')
        if [ -z "${active_manual_job_name}" ]; then
            echo "Manual Job was not found. There is not collision with Cronjob and manual Job. Ready to proceed."
            return 0
        fi

        # Manual Job has been detected and is running.
        # Lets now get the Cronjob name because we'll need to determine who ran first at this point.
        # Is it the Cronjob or Job?
        # Get CronJob name
        # CronJob name will always begin with "pingdirectory-periodic-backup" follow by a timestamp in its name.
        active_cronjob_job_name=$(get_actively_running_cronjob | head -n 1 | tr -d ' ')

        # Now that we have both names (Cronjob and manual Job).
        # We can sort the create timestamp and determine who ran first (Cronjob or manual Job).
        second_active_job_by_name=$(kubectl get jobs "${active_cronjob_job_name}" "${active_manual_job_name}" --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' -n "${NAMESPACE}" 2>/dev/null | sed -n '2p' | tr -d ' ')

        # Terminate second Job but the second Job should only terminate itself.
        # This is rare to happen but I found if 2 Jobs created at the same time may hit this condition
        # where they both will attempt to delete the 2nd Job. The 1st Job should simply ignore as the 2nd Job whose
        # the problem will simply delete itself and error out.
        current_job_name=$(get_current_job_name)
        if [ "${current_job_name}" != "${second_active_job_by_name}" ]; then
          echo "2 Jobs were triggered around the same time ${current_job_name} and ${second_active_job_by_name}. This Job ${current_job_name} is considered 1st. The Job ${second_active_job_by_name} will terminate itself. Ready to proceed with ${current_job_name}."
          return 0
        fi

        # Avoid interrupting backup that started first. Terminate the second Job only.
        echo "There is a backup already running at the moment. Terminating ${second_active_job_by_name} Job"

        # Before deleting this Job that ran second pause so the person can see the logs.
        sleep 30

        # Terminate second Job
        kubectl delete job "${second_active_job_by_name}" -n "${NAMESPACE}"
    else

        # Entering this condition means there is NOT an active Cronjob running.

        # Determine if there is another Manual Job running. We also need to avoid 2 manual Jobs from running.
        # Manual jobs can be found by filtering on "pd-manual=true" label.
        # We can sort the create timestamp and retrieve the 2nd manual Job if there is any.
        second_active_manual_job_by_name=$(get_actively_running_manual_jobs | sed -n '2p' | tr -d ' ')

        if [ -z "${second_active_manual_job_by_name}" ]; then
            echo "Second manual Job was not found. Ready to proceed."
            return 0
        fi

        # Terminate second Job but the second Job should only terminate itself.
        # This is rare to happen but I found if 2 Jobs created at the same time may hit this condition
        # where they both will attempt to delete the 2nd Job. The 1st Job should simply ignore as the 2nd Job whose
        # the problem will simply delete itself and error out.
        current_job_name=$(get_current_job_name)
        if [ "${current_job_name}" != "${second_active_manual_job_by_name}" ]; then
          echo "2 Jobs were triggered around the same time ${current_job_name} and ${second_active_manual_job_by_name}. This Job ${current_job_name} is considered 1st. The Job ${second_active_manual_job_by_name} will terminate itself. Ready to proceed with ${current_job_name}."
          return 0
        fi

        # Avoid interrupting manual backup Job that started first. Terminate the second Job only.
        echo "There is a manual backup already running at the moment. Terminating ${second_active_manual_job_by_name} Job"

        # Before deleting this Job that ran second pause so the person can see the logs.
        sleep 30

        # Terminate second Job
        kubectl delete job "${second_active_manual_job_by_name}" -n "${NAMESPACE}"
    fi

    return 1 # Default, exit method as there is another backup running.
             # This should never happen if there is not collision with Cronjob and manual Job.
}

# Function that retrieves the parent Job name. This is the Job that creates the backup Job.
get_current_job_name() {
  kubectl get pod "${CURRENT_JOB_POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.metadata.ownerReferences[0].name}' 2>/dev/null | tr -d ' '
}

# Function ensures that the pd-manual=true label is attached to manual Jobs. This is the only way p1as automation
# can filter out pingdirectory backups
is_required_label_for_manual_job_provided() {

    echo "Checking to see if this is a manual job"

    # Determine if Cronjob is actively running. This will be empty if CronJob is not running.
    active_cronjob_running=$(is_cronjob_running_now)
    if [ -z "${active_cronjob_running}" ]; then

      echo "This is a manual job. Evaluate that the job has the label 'pd-manual=true'"

      # This is a manual Job. To get the Job name use the pod metadata.ownerReferences
      current_manual_job_name=$(get_current_job_name)
      # Verify that manual Job is labelled correctly as 'pd-manual=true'.
      kubectl get job "${current_manual_job_name}" -n "${NAMESPACE}" -o jsonpath='{.metadata.labels.pd-manual}' | grep -q "true"
      if [ "$?" -ne "0" ]; then
        echo "Exiting. Manual Job must have the required label 'pd-manual=true'"

        # Before deleting this Job due to missing label pause so the person can see the logs.
        sleep 30

        # Terminate Job with missing required label
        kubectl delete job "${current_manual_job_name}" -n "${NAMESPACE}"

        return 1
      else
        echo "Required label 'pd-manual=true' was found for job. Proceeding with backup."
      fi
    else
      echo "This is a cronjob. Continue to proceed and ignore evaluating label"
    fi

    return 0 # This is a CronJob or the correct label was found for manual Job
}

# Function to determine if the true PingDirectory Job that perform backup and its own PVC allocated is actively running.
# The first argument allows you to try up to desired times before ending with an error.
is_pingdirectory_backup_running() {
  attempts="${1}"
  count=1

  while [ ${count} -le ${attempts} ]; do
    kubectl get job/"${BACKUP_NAME}" -n "${NAMESPACE}" > /dev/null
    pingdirectory_backup_job_status=$?

    kubectl get pvc/"${BACKUP_NAME}" -n "${NAMESPACE}" > /dev/null
    pingdirectory_backup_pvc_status=$?

    if [ "${pingdirectory_backup_job_status}" -eq "0" ] && [ "${pingdirectory_backup_pvc_status}" -eq "0" ]; then
      return 0  # PingDirectory backup Job found continue
    else
      sleep 5  # PingDirectory backup Job not found try again in a few seconds
    fi

    count=$((count + 1))  # Increment the counter
  done

  return 1 # Fail if Job and PVC is not found after several attempts
}

### Script execution begins here. ###

# This guarantees that cleanup_resources method will always run, even if the script exits due to an error
trap "cleanup_resources" EXIT

# Before kicking off the PD backup. Check the following conditions:
# 1) If there is a CronJob/manual Job collision.
# 2) If user created manual Job but without the appropriate label.
if ! is_only_one_backup_running || ! is_required_label_for_manual_job_provided; then
  # Avoid automation from deleting PVC. We need to avoid deleting if this is a CronJob/manual Job collision.
  SKIP_RESOURCE_CLEANUP="true"
  exit 1 # Technically, this is not a PingDirectory backup error but a CronJob/Manual Job collision or user error.
fi

# Before backup begins. Ensure lingering resources of Job and PVC have been removed when running prior backup
cleanup_resources

# Execute backup-ops.sh script (which kicks off the k8s pingdirectory-backup Job)
test -x ${SCRIPT} && ${SCRIPT} "p1as-automation"

# Ensure Job and PVC is available at all times. Try up to 10 times.
# Will end with error if pingdirectory-backup Job and PVC isn't present.
while is_pingdirectory_backup_running 10; do

  # The Job is running. The following logic will now check for completion on the Job K8s object
  if is_job_complete; then
    echo "${BACKUP_NAME} Job successfully completed. Cronjob will clean up the backup job PVC and Job resources"
    exit 0
  else

    # Job is not complete yet once in this else condition.

    # Now, check to ensure Job backofflimit/retries hasn't exceeded.
    # If so, immediately terminate Cronjob with error as its retries of backup Job has exceeded.
    # As of now we have backofflimit set to 0 in K8s Job 'pingdirectory-backup' so technically we shouldn't need this logic.
    # However, if this were to ever change. The cronjob is smart enough to keep Job and PVC until it has exceeded
    # its backofflimit/retry attempts of producing a backup.


    # Retrieve failed attempts of Job if exist and collect backofflimit/# of retries from Job K8s spec
    failed_attempts=$(get_failed_attempts)
    backoff_limit=$(get_backoff_limit)

    # If we can't find any failures assume Job is still running
    if [ -z "${failed_attempts}" ]; then
      echo "${BACKUP_NAME} Job is running but not complete. Waiting..."

    # Failed attempts was found check to see if it exceeds backofflimit. If so, we can stop the cronjob and report
    # as an error
    elif [ "${failed_attempts}" -ge "${backoff_limit}" ]; then
      echo "Job failed ${failed_attempts} times, with backofflimit of ${backoff_limit}. Job has exceeded its backofflimit/retries. Exiting with error..."
      echo "Cronjob will clean up the backup job PVC and Job resources"
      exit 1

    # Failed attempts have not exceeded. This means K8s Job pingdirectory-backup backofflimit hasn't exceeded so
    # The cronjob should be aware and avoid deleting the Job and PVC. Cronjob will continue to wait until backofflimit
    # has exceeded or until a successful completion of backup.
    else
      echo "Job failed ${failed_attempts} times, with backofflimit of ${backoff_limit}. ${BACKUP_NAME} Job is expected to retry."
    fi
  fi

  sleep 5  # Wait for 5 seconds before checking PingDirectory backup status
done

echo "The kubernetes job/${BACKUP_NAME} that triggers PingDirectory backup and its own PVC was not found. This is mandatory as something unexpectedly has happened to the pingdirectory-backup Job and the PVC."
exit 1