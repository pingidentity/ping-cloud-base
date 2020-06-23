#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"


if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

expected_files() {
  kubectl logs -n "${NAMESPACE}" \
    $(kubectl get pod -o name -n "${NAMESPACE}" | grep pingaccess-backup | cut -d/ -f2) |
  tail -1 |
  tr ' ' '\n' |
  sort
}

actual_files() {
  BUCKET_URL_NO_PROTOCOL=${BACKUP_URL#s3://}
  BUCKET_NAME=$(echo "${BUCKET_URL_NO_PROTOCOL}" | cut -d/ -f1)
  DAYS_AGO=1

  aws s3api list-objects \
    --bucket "${BUCKET_NAME}" \
    --prefix 'pingaccess/' \
    --query "reverse(sort_by(Contents[?LastModified>='${DAYS_AGO}'], &LastModified))[].Key" \
    --profile "${AWS_PROFILE}" |
  tr -d '",[]' |
  cut -d/ -f2 |
  sort
}

UPLOAD_JOB="${PROJECT_DIR}/k8s-configs/ping-cloud/base/pingaccess/aws/backup.yaml"

log "Applying backup job"
kubectl delete -f "${UPLOAD_JOB}" -n "${NAMESPACE}"
kubectl apply -f "${UPLOAD_JOB}" -n "${NAMESPACE}"

log "Waiting for backup job to complete"
kubectl wait --for=condition=complete --timeout=900s job/pingaccess-backup -n "${NAMESPACE}"

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

exit 0
