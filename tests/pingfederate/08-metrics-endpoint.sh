#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPingFederateMetricsEndpointExist() {
  PRODUCT_NAME=pingfederate
  SERVER=
  CONTAINER=

  ENGINE_SERVERS=$( kubectl get pod -o name -n "${PING_CLOUD_NAMESPACE}" -l role=${PRODUCT_NAME}-engine | grep ${PRODUCT_NAME} | cut -d/ -f2)
  SERVERS="${PRODUCT_NAME}-admin-0 ${ENGINE_SERVERS}"

  for SERVER in ${SERVERS}; do
    # Set the container name
    test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"
    curl_metrics ${SERVER} ${CONTAINER} >> /dev/null
    assertEquals "Metrics endpoint can't be reached on ${SERVER}" 0 $?
  done

  # If we get to this point signal to shunit that the test was successfull
  assertEquals 0 0
}

testPingFederateMetricsPublished() {
  PRODUCT_NAME=pingfederate
  SERVER=
  CONTAINER=

  ENGINE_SERVERS=$( kubectl get pod -o name -n "${PING_CLOUD_NAMESPACE}" -l role=${PRODUCT_NAME}-engine | grep ${PRODUCT_NAME} | cut -d/ -f2)
  SERVERS="${PRODUCT_NAME}-admin-0 ${ENGINE_SERVERS}"

  for SERVER in ${SERVERS}; do
    # Set the container name
    test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"
    metrics=$(curl_metrics ${SERVER} ${CONTAINER})
    assertContains "${metrics}" "org_eclipse_jetty_server_handler_statisticshandler_requestTimeMean"
    assertContains "${metrics}" "org_eclipse_jetty_server_handler_statisticshandler_requests"
  done

  # If we get to this point signal to shunit that the test was successfull
  assertEquals 0 0
}

curl_metrics() {
    SERVER=$1
    CONTAINER=$2
    
    kubectl exec -n ${PING_CLOUD_NAMESPACE} ${SERVER} -c ${CONTAINER} -- sh -c "curl -s localhost:8080/metrics"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
