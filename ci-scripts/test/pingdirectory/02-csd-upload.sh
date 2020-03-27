#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

expected_files() {
  kubectl logs -n "${NAMESPACE}" \
    $(kubectl get pod -o name -n "${NAMESPACE}" | grep pingdirectory-csd-upload | cut -d/ -f2) |
  tail -1 |
  tr ' ' '\n' |
  sort
}

actual_files() {
  BUCKET_URL_NO_PROTOCOL=${LOG_ARCHIVE_URL#s3://}
  BUCKET_NAME=$(echo "${BUCKET_URL_NO_PROTOCOL}" | cut -d/ -f1)

  aws s3api list-objects \
    --bucket "${BUCKET_NAME}" \
    --prefix 'pingdirectory/support-data' \
    --query "Contents[?contains(Key, \`${NAMESPACE}\`)][].Key" \
    --profile "${AWS_PROFILE}" |
  tr -d '",[]' |
  cut -d/ -f2 |
  sort
}

UPLOAD_JOB="${CI_PROJECT_DIR}/k8s-configs/ping-cloud/base/pingdirectory/aws/upload-csd.yaml"

log "Applying the CSD upload job"
kubectl delete -f "${UPLOAD_JOB}" -n "${NAMESPACE}"
kubectl apply -f "${UPLOAD_JOB}" -n "${NAMESPACE}"

log "Waiting for CSD upload job to complete"
kubectl wait --for=condition=complete --timeout=600s job/pingdirectory-csd-upload -n "${NAMESPACE}"

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