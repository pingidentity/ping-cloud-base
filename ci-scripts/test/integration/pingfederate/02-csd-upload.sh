#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPingFederateRuntimeCsdUpload() {
  local upload_csd_job_name=pingfederate-periodic-csd-upload
  csd_upload "${upload_csd_job_name}"
  assertEquals 0 $?
}

testPingFederateAdminCsdUpload() {
  local upload_csd_job_name=pingfederate-admin-periodic-csd-upload
  csd_upload "${upload_csd_job_name}"
  assertEquals 0 $?
}

csd_upload() {
  local upload_csd_job_name="${1}"
  local upload_job="${PROJECT_DIR}/k8s-configs/ping-cloud/base/pingfederate/aws/periodic-csd-upload.yaml"

  log "Applying the CSD upload job"
  kubectl delete -f "${upload_job}" -n "${NAMESPACE}"
  kubectl apply -f "${upload_job}" -n "${NAMESPACE}"
  kubectl create job --from=cronjob/${upload_csd_job_name} ${upload_csd_job_name} -n "${NAMESPACE}"

  log "Waiting for CSD upload job to complete"
  kubectl wait --for=condition=complete --timeout=900s job.batch/${upload_csd_job_name} -n "${NAMESPACE}"

  log "Expected CSD files:"
  expected_files "${upload_csd_job_name}" | tee /tmp/expected.txt

  if ! verify_upload_with_timeout "pingfederate"; then
    return 1
  fi
  return 0
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}