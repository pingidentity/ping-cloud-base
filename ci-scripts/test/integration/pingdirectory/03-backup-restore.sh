#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

expected_files() {
  kubectl logs -n "${NAMESPACE}" \
    $(kubectl get pod -o name -n "${NAMESPACE}" | grep pingdirectory-backup | cut -d/ -f2) |
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
    --prefix 'pingdirectory/' \
    --query "reverse(sort_by(Contents[?LastModified>='${DAYS_AGO}'], &LastModified))[].Key" \
    --profile "${AWS_PROFILE}" |
  tr -d '",[]' |
  cut -d/ -f2 |
  sort
}

BACKUP_JOB="${PROJECT_DIR}/k8s-configs/ping-cloud/base/pingdirectory/aws/backup.yaml"

log "Applying the backup job"
kubectl delete -f "${BACKUP_JOB}" -n "${NAMESPACE}"
kubectl apply -f "${BACKUP_JOB}" -n "${NAMESPACE}"

log "Waiting for the backup job to complete"
kubectl wait --for=condition=complete --timeout=900s job/pingdirectory-backup -n "${NAMESPACE}"

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

RESTORE_JOB="${PROJECT_DIR}/k8s-configs/ping-cloud/base/pingdirectory/aws/restore.yaml"

log "Applying the restore job"
kubectl delete -f "${RESTORE_JOB}" -n "${NAMESPACE}"
kubectl apply -f "${RESTORE_JOB}" -n "${NAMESPACE}"

log "Waiting for the restore job to complete"
kubectl wait --for=condition=complete --timeout=900s job/pingdirectory-restore -n "${NAMESPACE}"

# We expect 3 backends to be restored successfully
NUM_EXPECTED=3
RESTORE_SUCCESS_MESSAGE='Restore task .* has been successfully completed'
RESTORE_POD=$(kubectl get pod -n "${NAMESPACE}" -o name | grep pingdirectory-restore)
NUM_SUCCESSFUL=$(kubectl logs -n "${NAMESPACE}" "${RESTORE_POD}" | grep -c "${RESTORE_SUCCESS_MESSAGE}")

if test "${NUM_SUCCESSFUL}" -ne 4; then
  log "Restore job failed. Restore logs:"
  kubectl logs -n "${NAMESPACE}" "${RESTORE_POD}"
  exit 1
fi

exit 0