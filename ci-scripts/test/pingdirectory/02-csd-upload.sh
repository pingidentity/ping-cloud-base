#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

expected_files() {
  kubectl logs $(kubectl get pod -o name | grep pingdirectory-csd-upload | cut -d/ -f2) |
    tail -1 |
    tr ' ' "\n"
}

actual_files() {
  aws s3 ls "${LOG_ARCHIVE_URL}" |
    grep '^support-data' |
    awk '{ print $4 }' |
    sort -r
}

UPLOAD_JOB="${CI_PROJECT_DIR}/k8s-configs/ping-cloud/base/pingdirectory/upload-csd.yaml"

log "Applying the CSD upload job"
kubectl apply -f "${UPLOAD_JOB}" -n "${NAMESPACE}"

log "Waiting for CSD upload job to complete"
kubectl wait --for=condition=complete --timeout=300s job/pingdirectory-csd-upload -n "${NAMESPACE}"

log "Expected CSD files:"
expected_files | tee /tmp/expected.txt

log "Actual CSD files:"
actual_files | tee /tmp/actual.txt

log "Verifying that the expected files were uploaded"
NOT_UPLOADED=$(comm -23 /tmp/expected.txt /tmp/actual.txt)

if ! test -z "${NOT_UPLOADED}"; then
  log "The following files were not uploaded: ${NOT_UPLOADED}"
  exit 1
fi

exit 0