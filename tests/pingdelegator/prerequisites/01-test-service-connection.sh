#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testServiceConnection() {

  service_name="pingdelegator"
  exit_code=0

  # Get 1st delegator pod name
  delegator_pod_name=$(kubectl get pods \
        -n "${PING_CLOUD_NAMESPACE}" \
        -l role=pingdelegator \
        -o=jsonpath="{.items[0].metadata.name}")
  assertEquals "Failed to get pingdelegator pod name" 0 $?
  delegator_pod_name=$(echo "${delegator_pod_name}" | tr -s '[[:space:]]')
  
  # Get delegator service port number. e.g. 1443 
  delegator_pod_port=$(kubectl get service "${service_name}" \
                          -n "${PING_CLOUD_NAMESPACE}" -o json)
  assertEquals "Failed to get ${service_name} service" 0 $?

  delegator_pod_port=$(echo "${delegator_pod_port}" | jq -r '.spec.ports[].port')
  assertEquals "Failed to ${service_name} service port" 0 $?
  
  delegator_pod_port=$(echo "${delegator_pod_port}" | tr -s '[[:space:]]' '\n')

  # Test Ping Delegator service
  kubectl exec -it "${delegator_pod_name}" -n "${PING_CLOUD_NAMESPACE}" -- \
    curl -ssk -o /dev/null "https://${service_name}.${PING_CLOUD_NAMESPACE}.svc.cluster.local:${delegator_pod_port}/delegator"
  exit_code=$?
  
  assertEquals "The Ping Delegated Admin service '${service_name}:${delegator_pod_port}' is inaccessible." 0 $exit_code
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}