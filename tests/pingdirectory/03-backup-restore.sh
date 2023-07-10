#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}" > /dev/null
. "${CI_SCRIPTS_DIR}"/test/test_utils.sh

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

expected_files() {
  kubectl logs -n "${PING_CLOUD_NAMESPACE}" \
    $(kubectl get pod -o name -n "${PING_CLOUD_NAMESPACE}" | grep pingdirectory-backup | cut -d/ -f2) |
  tail -10 |
  tr ' ' '\n' |
  sort |
  grep '^data.*zip$' |
  uniq 
}

actual_files() {
  BUCKET_URL_NO_PROTOCOL=${BACKUP_URL#s3://}
  BUCKET_NAME=$(echo "${BUCKET_URL_NO_PROTOCOL}" | cut -d/ -f1)
  DAYS_AGO=1

  aws s3api list-objects \
    --bucket "${BUCKET_NAME}" \
    --prefix 'pingdirectory/' \
    --query "reverse(sort_by(Contents[?LastModified>='${DAYS_AGO}'], &LastModified))[].Key" \
    --profile "${AWS_PROFILE}" |
  tr -d '",[]' |
  cut -d/ -f2 |
  sort
}

testBackupAndRestore() {

  BACKUP_JOB="${PROJECT_DIR}"/k8s-configs/ping-cloud/base/pingdirectory/server/aws/backup.yaml

  log "Applying the backup job"
  kubectl delete -f "${BACKUP_JOB}" -n "${PING_CLOUD_NAMESPACE}"

  kubectl apply -f "${BACKUP_JOB}" -n "${PING_CLOUD_NAMESPACE}"
  assertEquals "The kubectl apply command to create the ${BACKUP_JOB} should have succeeded" 0 $?

  log "Waiting for the backup job to complete"
  kubectl wait --for=condition=complete --timeout=900s job/pingdirectory-backup -n "${PING_CLOUD_NAMESPACE}"
  assertEquals "The kubectl wait command for the job should have succeeded" 0 $?

  log "Expected backup files:"
  expected_files | tee /tmp/expected.txt

  log "Actual backup files:"
  actual_files | tee /tmp/actual.txt

  log "Verifying that the expected files were uploaded"
  NOT_UPLOADED=$(comm -23 /tmp/expected.txt /tmp/actual.txt)

  if ! test -z "${NOT_UPLOADED}"; then
    log "The following files were not uploaded: ${NOT_UPLOADED}"
    exit 1
  fi

  RESTORE_JOB="${PROJECT_DIR}"/k8s-configs/ping-cloud/base/pingdirectory/server/aws/restore.yaml

  log "Applying the restore job"
#   kubectl delete -f "${RESTORE_JOB}" -n "${PING_CLOUD_NAMESPACE}"
  kubectl apply -f "${RESTORE_JOB}" -n "${PING_CLOUD_NAMESPACE}"
  assertEquals "The kubectl apply command to create the ${RESTORE_JOB} should have succeeded" 0 $?

  log "Waiting for the restore job to complete"
  kubectl wait --for=condition=complete --timeout=900s job/pingdirectory-restore -n "${PING_CLOUD_NAMESPACE}"
  assertEquals "The kubectl wait command for the job should have succeeded" 0 $?

  # We expect 3 backends to be restored successfully
  RESTORE_SUCCESS_MESSAGE='Restore task .* has been successfully completed'
  RESTORE_POD=$(kubectl get pod -n "${PING_CLOUD_NAMESPACE}" -o name | grep pingdirectory-restore)
  NUM_SUCCESSFUL=$(kubectl logs -n "${PING_CLOUD_NAMESPACE}" "${RESTORE_POD}" | grep -o "${RESTORE_SUCCESS_MESSAGE}" | sort -u | wc -l )

  NUM_EXPECTED=3
  assertEquals "Restore job failed" "${NUM_EXPECTED}" "${NUM_SUCCESSFUL}"
  if test "${NUM_SUCCESSFUL}" -ne ${NUM_EXPECTED}; then
    log "Restore job failed. Restore logs:"
    kubectl logs -n "${PING_CLOUD_NAMESPACE}" "${RESTORE_POD}"
  fi
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}