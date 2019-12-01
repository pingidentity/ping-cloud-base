#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

log "Fetching current count of files at ${LOG_ARCHIVE_URL}"
CURRENT_COUNT=$(aws s3 ls --recursive "${LOG_ARCHIVE_URL}" --profile "${AWS_PROFILE}" | wc -l | awk '{ print $1 }')
log "Current count: ${CURRENT_COUNT}"

UPLOAD_JOB="${CI_PROJECT_DIR}/k8s-configs/ping-cloud/base/pingdirectory/upload-csd.yaml"

log "Applying the CSD upload job"
kubectl apply -f "${UPLOAD_JOB}" -n "${NAMESPACE}"

log "Waiting for CSD upload job to complete"
kubectl wait --for=condition=complete --timeout=300s job/ds-csd-upload -n "${NAMESPACE}"

log "Fetching new count of files at ${LOG_ARCHIVE_URL}"
NEW_COUNT=$(aws s3 ls --recursive "${LOG_ARCHIVE_URL}" --profile "${AWS_PROFILE}" | wc -l | awk '{ print $1 }')
log "New count: ${NEW_COUNT}"

log "Deleting the CSD upload job"
kubectl delete -f "${UPLOAD_JOB}" -n "${NAMESPACE}"

# The new count can be 2 more than the old count if the periodic CSD upload happened to run at about the same time
log "Verifying that new count is 1 or 2 greater than old count"
DIFF=$((${NEW_COUNT} - ${CURRENT_COUNT}))

test ${DIFF} -ne 1 && test ${DIFF} -ne 2 && exit 1 || exit 0