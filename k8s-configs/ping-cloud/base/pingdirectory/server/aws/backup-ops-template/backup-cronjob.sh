#!/bin/sh

# Variables
BACKUP_NAME="pingdirectory-backup"
NAMESPACE="ping-cloud"
SCRIPT="/opt/in/backup-ops.sh"

# Functions
# Function to get the full pod name based on the prefix name 'pingdirectory-backup'
get_pod_name() {
  kubectl get pods -n "${NAMESPACE}" --no-headers -o custom-columns=":metadata.name" | grep "^${BACKUP_NAME}" | head -n 1
}

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
  kubectl get job "${BACKUP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.backoffLimit}'
}

# Function to delete Job and its PVC if detected in cluster
cleanup_resources() {
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

### Script execution begins here. ###

# This guarantees that cleanup_resources method will always run, even if the script exits due to an error
trap "cleanup_resources" EXIT

# Before backup begins. Ensure lingering resources of Job and PVC have been removed when running prior backup
cleanup_resources

# Execute backup-ops.sh script (which kicks off the k8s pingdirectory-backup Job)
test -x ${SCRIPT} && ${SCRIPT} "scheduled-cronjob"

# Wait for Job to be in 'Complete' state
while true; do

  # Verify the pod of the Job has been deployed before checking Job state.
  POD_NAME=$(get_pod_name)
  if [ -z "${POD_NAME}" ]; then
    echo "Pod with prefix ${BACKUP_NAME} not found. Waiting for ${BACKUP_NAME} Job to deploy..."
  else

    # The pod of the Job is running. The following logic will now check for completion on the Job K8s object
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
  fi

  sleep 5  # Wait for 5 seconds before checking again
done