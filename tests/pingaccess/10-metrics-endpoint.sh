#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPingAccessMetricsEndpointExist() {
  PRODUCT_NAME=pingaccess
  SERVER=
  CONTAINER=

  SERVERS=$( kubectl get pod -o name -n "${PING_CLOUD_NAMESPACE}" -l role=${PRODUCT_NAME}-engine | grep ${PRODUCT_NAME} | cut -d/ -f2)

  for SERVER in ${SERVERS}; do
    # Set the container name
    CONTAINER="${PRODUCT_NAME}"
    curl_metrics ${SERVER} ${CONTAINER} >> /dev/null
    assertEquals "Metrics endpoint can't be reached on ${SERVER}" 0 $?
  done
}

 testPingAccessMetricsPublished() {
   PRODUCT_NAME=pingaccess
   SERVER=
   CONTAINER=

   SERVERS=$( kubectl get pod -o name -n "${PING_CLOUD_NAMESPACE}" -l role=${PRODUCT_NAME}-engine | grep ${PRODUCT_NAME} | cut -d/ -f2)

   for SERVER in ${SERVERS}; do
     # Set the container name
     CONTAINER="${PRODUCT_NAME}"
     metrics=$(curl_metrics ${SERVER} ${CONTAINER})
     assertContains "${metrics}" "jvm_memory_bytes_used"
     assertContains "${metrics}" "jmx_exporter_build_info"
   done
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
