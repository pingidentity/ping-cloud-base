#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"
. "${CI_SCRIPTS_DIR}"/test/test_utils.sh

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPingDirectoryCsdUpload() {
  local upload_csd_job_name=pingdirectory-csd-upload
  local upload_job="${PROJECT_DIR}"/k8s-configs/ping-cloud/base/pingdirectory/server/aws/upload-csd.yaml

  log "Applying the CSD upload job"
  kubectl delete -f "${upload_job}" -n "${PING_CLOUD_NAMESPACE}"
  kubectl apply -f "${upload_job}" -n "${PING_CLOUD_NAMESPACE}"

  log "Waiting for CSD upload job to complete"
  kubectl wait --for=condition=complete --timeout=900s job/pingdirectory-csd-upload -n "${PING_CLOUD_NAMESPACE}"

  log "Expected CSD files:"
  expected_files "${upload_csd_job_name}" | tee /tmp/expected.txt

  sleep 5

  verify_upload_with_timeout "csd-logs/pingdirectory"
  assertEquals 0 $?
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}