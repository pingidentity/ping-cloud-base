#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

declare -a UPLOAD_CSD_JOB_NAMES=("pingaccess-periodic-csd-upload" "pingaccess-admin-periodic-csd-upload")

expected_files() {
  UPLOAD_CSD_JOB_PODS=$(kubectl get pod -o name -n "${NAMESPACE}" -o name | grep "${UPLOAD_CSD_JOB_NAME}" | cut -d/ -f2)
  for UPLOAD_CSD_JOB_POD in $UPLOAD_CSD_JOB_PODS
  do
    kubectl logs -n "${NAMESPACE}" ${UPLOAD_CSD_JOB_POD} |
    tail -1 |
    tr ' ' '\n' |
    sort
  done
}

actual_files() {
  BUCKET_URL_NO_PROTOCOL=${LOG_ARCHIVE_URL#s3://}
  BUCKET_NAME=$(echo "${BUCKET_URL_NO_PROTOCOL}" | cut -d/ -f1)

  DIRECTORY_NAME=pingaccess

  UPLOAD_CSD_JOB_POD_PREFIX=$(echo "${UPLOAD_CSD_JOB_NAME}" | sed 's/-periodic-csd-upload$//')
  CURRENT_DATE=$(date +"%Y%m%d")

  aws s3 ls \
    "${BUCKET_NAME}"/"${DIRECTORY_NAME}"/ \
    --recursive | 
    grep "${CURRENT_DATE}[0-9]*-support-data-ping-${UPLOAD_CSD_JOB_POD_PREFIX}" | 
    cut -c 32- | 
    xargs basename | 
    sort |
    if [[ "$UPLOAD_CSD_JOB_POD_PREFIX" == "pingaccess" ]];
    then 
        cat | grep -v "admin"
    else
        cat
    fi
}

UPLOAD_JOBS="${PROJECT_DIR}/k8s-configs/ping-cloud/base/pingaccess/aws/periodic-csd-upload.yaml"

log "Applying the CSD upload job"
kubectl delete -f "${UPLOAD_JOBS}" -n "${NAMESPACE}"
kubectl apply -f "${UPLOAD_JOBS}" -n "${NAMESPACE}"

for UPLOAD_CSD_JOB_NAME in "${UPLOAD_CSD_JOB_NAMES[@]}"
do
    kubectl create job --from=cronjob/${UPLOAD_CSD_JOB_NAME} ${UPLOAD_CSD_JOB_NAME} -n "${NAMESPACE}"

    log "Waiting for CSD upload job to complete"
    kubectl wait --for=condition=complete --timeout=900s job.batch/${UPLOAD_CSD_JOB_NAME} -n "${NAMESPACE}"

    log "Expected CSD files:"
    expected_files | tee /tmp/${UPLOAD_CSD_JOB_NAME}-expected.txt

    log "Actual CSD files:"
    actual_files | tee /tmp/${UPLOAD_CSD_JOB_NAME}-actual.txt

    log "Verifying that the expected files were uploaded"
    NOT_UPLOADED=$(comm -23 /tmp/${UPLOAD_CSD_JOB_NAME}-expected.txt /tmp/${UPLOAD_CSD_JOB_NAME}-actual.txt)

    sleep 10

    if ! test -z "${NOT_UPLOADED}"; then
    log "The following files were not uploaded: ${NOT_UPLOADED}"
    exit 1
    fi
done

exit 0