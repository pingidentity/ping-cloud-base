#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

get_expected_files() {
  kubectl logs -n "${NAMESPACE}" \
    $(kubectl get pod -o name -n "${NAMESPACE}" | grep pingfederate-backup | cut -d/ -f2) |
  tail -1 |
  tr ' ' '\n' |
  sort
}

get_actual_files() {
  BUCKET_URL_NO_PROTOCOL=${BACKUP_URL#s3://}
  BUCKET_NAME=$(echo "${BUCKET_URL_NO_PROTOCOL}" | cut -d/ -f1)
  DAYS_AGO=1

  aws s3api list-objects \
    --bucket "${BUCKET_NAME}" \
    --prefix 'pingfederate/' \
    --query "reverse(sort_by(Contents[?LastModified>='${DAYS_AGO}'], &LastModified))[].Key" \
    --profile "${AWS_PROFILE}" |
  tr -d '",[]' |
  cut -d/ -f2 |
  sort
}

testPingFederateBackup() {
  UPLOAD_JOB="${PROJECT_DIR}"/k8s-configs/ping-cloud/base/pingfederate/admin/aws/backup.yaml

  log "Applying backup job"
  kubectl delete -f "${UPLOAD_JOB}" -n "${NAMESPACE}"

  kubectl apply -f "${UPLOAD_JOB}" -n "${NAMESPACE}"
  assertEquals "The kubectl apply command to create the PingFederate upload jo should have succeeded" 0 $?

  log "Waiting for backup job to complete"
  kubectl wait --for=condition=complete --timeout=900s job/pingfederate-backup -n "${NAMESPACE}"
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

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
