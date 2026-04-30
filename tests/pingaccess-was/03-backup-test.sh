#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"
. "${CI_SCRIPTS_DIR}"/test/test_utils.sh

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

BACKUP_JOB_NAME="pingaccess-was-backup"

get_expected_files() {
  kubectl logs -n "${PING_CLOUD_NAMESPACE}" \
    $(kubectl get pod -o name -n "${PING_CLOUD_NAMESPACE}" | grep "${BACKUP_JOB_NAME}" | cut -d/ -f2) |
  tail -1 |
  tr ' ' '\n' |
  sort
}

get_actual_files() {
  local bucket_url=$(get_ssm_val "${BACKUP_URL#ssm:/}")
  local bucket_url_no_protocol=${bucket_url#s3://}
  DAYS_AGO=1

  aws s3api list-objects \
    --bucket "${bucket_url_no_protocol}" \
    --prefix 'pingaccess-was/' \
    --query "reverse(sort_by(Contents[?LastModified>='${DAYS_AGO}'], &LastModified))[].Key" \
    --profile "${AWS_PROFILE}" |
  tr -d '",[]' |
  cut -d/ -f2 |
  sort
}

########################################################################################################################
# Simulates a backup job failure for PingAccess WAS admin
# Arguments
#   ${1} -> Base name of pod w/o number appended (i.e pingaccess-was-admin)
#   ${2} -> The name of the Job to be created
#   ${3} -> Number of seconds to wait before checking state of job
#   returns 1 or 0 depending on state of job
########################################################################################################################
init_backup_job_failure() {
  local pod_name="${1}"
  local job_name="${1%-admin}-backup"
  local upload_job="${2}"
  local timeout="${3:-10}"

  log "Deleting backup job"
  kubectl delete job "${upload_job}" -n "${PING_CLOUD_NAMESPACE}" --ignore-not-found=true

  log "Disabling upload backup hook script"
  kubectl exec "${pod_name}-0" -c "${pod_name}" -n "${PING_CLOUD_NAMESPACE}" -- sh -c "sed -i '1i exit 1' /opt/staging/hooks/90-upload-backup-s3.sh"

  log "Creating backup job"
  kubectl create job --from=cronjob/pingaccess-was-periodic-backup "${upload_job}" -n "${PING_CLOUD_NAMESPACE}"
  assertEquals "The 'kubectl create' command to create the backup job should have succeeded" 0 $?

  log "Waiting for backup job to fail"
  sleep "${timeout}"
  verify_resource "job" "${PING_CLOUD_NAMESPACE}" "${job_name}"
  job_succeeded=${?}

  log "Re-enabling backup hook script"
  kubectl exec "${pod_name}-0" -c "${pod_name}" -n "${PING_CLOUD_NAMESPACE}" -- sh -c "sed -i '1d' /opt/staging/hooks/90-upload-backup-s3.sh"

  log "Deleting backup job"
  kubectl delete job "${upload_job}" -n "${PING_CLOUD_NAMESPACE}" --ignore-not-found=true

  return "${job_succeeded}"
}

oneTimeSetUp(){
  # Save off backup file in case test does not complete and leaves it with 1 or more 'exit 1' statements inserted into it
  kubectl exec pingaccess-was-admin-0 -c pingaccess-was-admin -n "${PING_CLOUD_NAMESPACE}" -- sh -c 'cp /opt/staging/hooks/90-upload-backup-s3.sh /tmp/90-upload-backup-s3.sh'
}

oneTimeTearDown(){
  # Revert the original file back when tests are done execting
  kubectl exec pingaccess-was-admin-0 -c pingaccess-was-admin -n "${PING_CLOUD_NAMESPACE}" -- sh -c 'cp /tmp/90-upload-backup-s3.sh /opt/staging/hooks/90-upload-backup-s3.sh'
}

testPingAccessBackup() {
  log "Applying backup job"
  kubectl delete job "${BACKUP_JOB_NAME}" -n "${PING_CLOUD_NAMESPACE}" --ignore-not-found=true > /dev/null 2>&1

  kubectl create job --from=cronjob/pingaccess-was-periodic-backup "${BACKUP_JOB_NAME}" -n "${PING_CLOUD_NAMESPACE}"
  assertEquals "The 'kubectl create' command to create the backup job should have succeeded" 0 $?

  log "Waiting for backup job to complete"
  kubectl wait --for=condition=complete --timeout=900s job/"${BACKUP_JOB_NAME}" -n "${PING_CLOUD_NAMESPACE}"
  assertEquals "The kubectl wait command for the backup job should have succeeded" 0 $?

  sleep 10

  log "Expected backup files:"
  expected_results=$(get_expected_files)
  echo "${expected_results}"

  log "Actual backup files:"
  actual_results=$(get_actual_files)
  echo "${actual_results}"

  assertContains "The expected_files were not contained within the actual_files" "${actual_results}" "${expected_results}"
}

testPingAccessBackupCapturesFailure() {
  init_backup_job_failure "pingaccess-was-admin" "${BACKUP_JOB_NAME}"
  assertEquals "Backup job should not have succeeded" 1 $?
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
