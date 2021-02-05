#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPingDirectoryCsdUpload() {
  local upload_csd_job_name=pingdirectory-csd-upload
  local upload_job="${PROJECT_DIR}"/k8s-configs/ping-cloud/base/pingdirectory/server/aws/upload-csd.yaml

  log "Applying the CSD upload job"
  kubectl delete -f "${upload_job}" -n "${NAMESPACE}"
  kubectl apply -f "${upload_job}" -n "${NAMESPACE}"

  log "Waiting for CSD upload job to complete"
  kubectl wait --for=condition=complete --timeout=900s job/pingdirectory-csd-upload -n "${NAMESPACE}"

  log "Expected CSD files:"
  expected_files "${upload_csd_job_name}" | tee /tmp/expected.txt

  sleep 5

  verify_upload_with_timeout "pingdirectory"
  assertEquals 0 $?
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}