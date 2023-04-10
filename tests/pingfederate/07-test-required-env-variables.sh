#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi


testRequiredEnvVars() {
  # The list of variables that are required to be set within product container. Append to string if you'd like to test more variables.
  REQUIRED_VARS='BACKUP_URL LOG_ARCHIVE_URL'
  PRODUCT_NAME=pingfederate

  ENGINE_SERVERS=$( kubectl get pod -o name -n "${PING_CLOUD_NAMESPACE}" -l role=${PRODUCT_NAME}-engine | grep ${PRODUCT_NAME} | cut -d/ -f2)

  # Prepend admin server to list of runtime engine servers
  SERVERS="${PRODUCT_NAME}-admin-0 ${ENGINE_SERVERS}"
  STATUS=0
  for SERVER in ${SERVERS}; do

    # Set the container name
    test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"

    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    # Extract environment variables from container
    CONTAINER_ENV_VARS=$( kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c "printenv" )

    for CURRENT_VAR_NAME in ${REQUIRED_VARS}; do
        CURRENT_VAR_VALUE=$( echo "${CONTAINER_ENV_VARS}" | grep "${CURRENT_VAR_NAME}=" | cut -d= -f2 )

        (test -z ${CURRENT_VAR_VALUE} ||
            test ${CURRENT_VAR_VALUE} == "unused") &&
            log "Environment variable, ${CURRENT_VAR_NAME}, is required, but is currently unset" &&
            STATUS=1
    done
  done

  # Fail test if a required variable is unset or set to "unused"
  assertEquals 0 ${STATUS}
  log "${PRODUCT_NAME} 07-test-required-env-variables.sh passed"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}