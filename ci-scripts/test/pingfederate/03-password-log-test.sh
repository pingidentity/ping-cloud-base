#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. "${SCRIPT_HOME}"/../../common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

TEMP_LOG_FILE=$(mktemp)
PRODUCT_NAME=pingfederate
SERVER=
CONTAINER=


ENGINE_SERVERS=$( kubectl get pod -o name -n "${NAMESPACE}" -l role=${PRODUCT_NAME}-engine | grep ${PRODUCT_NAME} | cut -d/ -f2)

# Prepend admin server to list of runtime engine servers
SERVERS="${PRODUCT_NAME}-admin-0 ${ENGINE_SERVERS}"
for SERVER in ${SERVERS}; do

  # Set the container name
  test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"

  log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

  set +x
  # Set temp log file
  set_log_file "${SERVER}" "${CONTAINER}" ${TEMP_LOG_FILE}

  # Extract environment variables from container
  ENV_VARS=$( kubectl exec ${SERVER} -n "${NAMESPACE}" -c "${CONTAINER}" -- sh -c "printenv" )

  # Retrieve all PingFederate passwords
  PF_ADMIN_USER_PASSWORD=$( echo "${ENV_VARS}" | grep "PF_ADMIN_USER_PASSWORD=" | cut -d= -f2 )
  PF_LDAP_PASSWORD=$( echo "${ENV_VARS}" | grep "PF_LDAP_PASSWORD=" | cut -d= -f2 )
  GIT_PASS=$( echo "${ENV_VARS}" | grep "GIT_PASS=" | cut -d= -f2 )

  # Create regex pattern of all possible passwords
  PATTERN=
  for CURRENT_PASSWORD in ${PF_ADMIN_USER_PASSWORD} \
                          ${PF_LDAP_PASSWORD} \
                          ${GIT_PASS}; do
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
  set -x

  # Fail test if error occured within check_for_password_in_logs function
  test "${TEST_RESULT}" == "1" && exit 1

done

rm ${TEMP_LOG_FILE}
log "${PRODUCT_NAME} password_log_test.sh passed" exit 0