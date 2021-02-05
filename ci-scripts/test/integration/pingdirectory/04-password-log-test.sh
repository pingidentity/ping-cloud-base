#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

TEMP_LOG_FILE=$(mktemp)
PRODUCT_NAME=pingdirectory
SERVER=
CONTAINER=

NUM_REPLICAS=$(kubectl get statefulset "${PRODUCT_NAME}" -o jsonpath='{.spec.replicas}' -n "${NAMESPACE}")
NUM_REPLICAS=$((NUM_REPLICAS - 1))

while test ${NUM_REPLICAS} -gt -1; do

  SERVER="${PRODUCT_NAME}-${NUM_REPLICAS}"
  CONTAINER="${PRODUCT_NAME}"

  log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

  set +x
  # Set temp log file
  set_log_file "${SERVER}" "${CONTAINER}" ${TEMP_LOG_FILE}

  # Extract environment variables from container
  ENV_VARS=$( kubectl exec ${SERVER} -n "${NAMESPACE}" -c "${CONTAINER}" -- sh -c "printenv" )

  # Retrieve all PingDirectory passwords
  PF_LDAP_PASSWORD=$( echo "${ENV_VARS}" | grep "PF_LDAP_PASSWORD=" | cut -d= -f2 )
  ROOT_USER_PASSWORD=$( echo "${ENV_VARS}" | grep "ROOT_USER_PASSWORD=" | cut -d= -f2 )
  GIT_PASS=$( echo "${ENV_VARS}" | grep "GIT_PASS=" | cut -d= -f2 )
  PF_ADMIN_USER_PASSWORD=$( echo "${ENV_VARS}" | grep "PF_ADMIN_USER_PASSWORD=" | cut -d= -f2 )
 
  # Create regex pattern of all possible passwords
  PATTERN=
  for CURRENT_PASSWORD in ${PF_LDAP_PASSWORD} \
                          ${ROOT_USER_PASSWORD} \
                          ${GIT_PASS} \
                          ${PF_ADMIN_USER_PASSWORD}; do
    if ! test -z "${CURRENT_PASSWORD}"; then
        test -z "${PATTERN}" && PATTERN="${CURRENT_PASSWORD}" || PATTERN="${PATTERN}\|${CURRENT_PASSWORD}"
    fi
  done
 
  TEST_RESULT=
  # Search for all passwords within logs
  if ! test -z ${PATTERN}; then
    check_for_password_in_logs "${SERVER}" "${PATTERN}" ${TEMP_LOG_FILE}
    TEST_RESULT=${?}
  fi

  # Fail test if error occured within check_for_password_in_logs function
  test "${TEST_RESULT}" == "1" && exit 1

  NUM_REPLICAS=$((NUM_REPLICAS - 1))
done

rm ${TEMP_LOG_FILE}
log "${PRODUCT_NAME} password_log_test.sh passed" exit 0