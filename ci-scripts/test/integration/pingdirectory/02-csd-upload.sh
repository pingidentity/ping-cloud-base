#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

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
  DAYS_AGO=1

  aws s3api list-objects \
    --bucket "${BUCKET_NAME}" \
    --prefix 'pingdirectory/support-data' \
    --query "reverse(sort_by(Contents[?LastModified>='${DAYS_AGO}'], &LastModified))[].Key" \
    --profile "${AWS_PROFILE}" |
  tr -d '",[]' |
  cut -d/ -f2 |
  sort
}

UPLOAD_JOB="${PROJECT_DIR}/k8s-configs/ping-cloud/base/pingdirectory/aws/upload-csd.yaml"

log "Applying the CSD upload job"
kubectl delete -f "${UPLOAD_JOB}" -n "${NAMESPACE}"
kubectl apply -f "${UPLOAD_JOB}" -n "${NAMESPACE}"

log "Waiting for CSD upload job to complete"
kubectl wait --for=condition=complete --timeout=900s job/pingdirectory-csd-upload -n "${NAMESPACE}"

log "Expected CSD files:"
expected_files | tee /tmp/expected.txt

log "Actual CSD files:"
actual_files | tee /tmp/actual.txt

log "Verifying that the expected files were uploaded"
NOT_UPLOADED=$(comm -23 /tmp/expected.txt /tmp/actual.txt)

sleep 10

if ! test -z "${NOT_UPLOADED}"; then
  log "The following files were not uploaded: ${NOT_UPLOADED}"
  exit 1
fi

exit 0
