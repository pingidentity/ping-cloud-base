#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  # The list of variables that are required to be set within product container. Append to string if you'd like to test more variables.
  REQUIRED_VARS='BACKUP_URL LOG_ARCHIVE_URL PD_MONITOR_BUCKET_URL'
  PRODUCT_NAME="pingdirectory"

  NUM_REPLICAS=$(kubectl get statefulset "${PRODUCT_NAME}" -o jsonpath='{.spec.replicas}' -n "${PING_CLOUD_NAMESPACE}")
}

testRequiredEnvironmentVariablesAreSet() {

  # Verify that there is at least 1 PD server to test
  assertTrue "PD servers don't exist, test needs at least 1 server running" "[ ${NUM_REPLICAS} -gt 0 ]"

  STATUS=0
  NUM_REPLICAS=$((NUM_REPLICAS - 1))
  while test ${NUM_REPLICAS} -gt -1; do
      SERVER="${PRODUCT_NAME}-${NUM_REPLICAS}"
      CONTAINER="${PRODUCT_NAME}"

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

      NUM_REPLICAS=$((NUM_REPLICAS - 1))
  done

  assertEquals 0 ${STATUS}
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}