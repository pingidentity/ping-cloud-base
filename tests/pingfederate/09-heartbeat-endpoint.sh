#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPingFederateHeartbeatEndpointExist() {
  PRODUCT_NAME=pingfederate
  SERVER=
  CONTAINER=

  SERVERS=$( kubectl get pod -o name -n "${PING_CLOUD_NAMESPACE}" -l role=${PRODUCT_NAME}-engine | grep ${PRODUCT_NAME} | cut -d/ -f2)

  for SERVER in ${SERVERS}; do
    # Set the container name
    test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"
    curl_heartbeat ${SERVER} ${CONTAINER} >> /dev/null
    assertEquals "Metrics endpoint can't be reached on ${SERVER}" 0 $?
  done

  # If we get to this point signal to shunit that the test was successfull
  assertEquals 0 0
}

 testPingFederateHeartbeatPublished() {
   PRODUCT_NAME=pingfederate
   SERVER=
   CONTAINER=

   SERVERS=$( kubectl get pod -o name -n "${PING_CLOUD_NAMESPACE}" -l role=${PRODUCT_NAME}-engine | grep ${PRODUCT_NAME} | cut -d/ -f2)

   for SERVER in ${SERVERS}; do
     # Set the container name
     test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"
     metrics=$(curl_heartbeat ${SERVER} ${CONTAINER})
     assertContains "${metrics}" "metric_pingfederate_idp_session_registry_session_map_size"
     assertContains "${metrics}" "metric_pingfederate_response_concurrency_statistics_90_percentile"
     assertContains "${metrics}" "metric_pingfederate_response_concurrency_statistics_mean"
     assertContains "${metrics}" "metric_pingfederate_response_statistics_count"
     assertContains "${metrics}" "metric_pingfederate_response_time_statistics_90_percentile"
     assertContains "${metrics}" "metric_pingfederate_response_time_statistics_mean"
     assertContains "${metrics}" "metric_pingfederate_session_state_attribute_map_size"
     assertContains "${metrics}" "metric_pingfederate_sp_session_registry_session_map_size"
     assertContains "${metrics}" "metric_pingfederate_total_failed_transactions"
     assertContains "${metrics}" "metric_pingfederate_total_transactions"
   done

   # If we get to this point signal to shunit that the test was successfull
   assertEquals 0 0
 }

curl_heartbeat() {
    SERVER=$1
    CONTAINER=$2
    
    kubectl exec -n ${PING_CLOUD_NAMESPACE} ${SERVER} -c ${CONTAINER} -- sh -c "curl -s localhost:8079"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
