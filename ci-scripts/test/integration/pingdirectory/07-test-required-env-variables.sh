#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# The list of variables that are required to be set within product container. Append to string if you'd like to test more variables.
REQUIRED_VARS='BACKUP_URL LOG_ARCHIVE_URL'
PRODUCT_NAME="pingdirectory"

NUM_REPLICAS=$(kubectl get statefulset "${PRODUCT_NAME}" -o jsonpath='{.spec.replicas}' -n "${NAMESPACE}")
NUM_REPLICAS=$((NUM_REPLICAS - 1))

while test ${NUM_REPLICAS} -gt -1; do

    SERVER="${PRODUCT_NAME}-${NUM_REPLICAS}"
    CONTAINER="${PRODUCT_NAME}"

    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    # Extract environment variables from container
    set +x
    CONTAINER_ENV_VARS=$( kubectl exec ${SERVER} -n "${NAMESPACE}" -c "${CONTAINER}" -- sh -c "printenv" )
    set -x

    for CURRENT_VAR_NAME in ${REQUIRED_VARS}; do
        set +x
        CURRENT_VAR_VALUE=$( echo "${CONTAINER_ENV_VARS}" | grep "${CURRENT_VAR_NAME}=" | cut -d= -f2 )
        set -x

        (test -z ${CURRENT_VAR_VALUE} || 
            test ${CURRENT_VAR_VALUE} == "unused") && 
            log "Environment variable, ${CURRENT_VAR_NAME}, is required, but is currently unset" && 
            STATUS=1
    done

    NUM_REPLICAS=$((NUM_REPLICAS - 1))
done

# Fail test if a required variable is unset or set to "unused"
test ${STATUS} -eq 1 && exit 1
log "${PRODUCT_NAME} 07-test-required-env-variables.sh passed"