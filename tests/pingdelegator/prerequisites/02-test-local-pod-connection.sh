#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPodConnection() {

  pod_label_name="role=pingdelegator"
  exit_code=0

  # Get all pingdelegator pod names
  delegator_pod_names=$(kubectl get pods \
                          -n "${PING_CLOUD_NAMESPACE}" \
                          -l ${pod_label_name} \
                          -o=jsonpath="{.items[*].metadata.name}")
  assertEquals "Failed to get pingdelegator pod name" 0 $?
  delegator_pod_names=$(echo "${delegator_pod_names}" | tr -s '[[:space:]]')

  # Get delegator pod port number. e.g. 1443 
  delegator_pod_port=$(kubectl get pods \
                          -n "${PING_CLOUD_NAMESPACE}" \
                          -l ${pod_label_name} \
                          -o jsonpath="{.items[0].spec.containers[*].ports[*].containerPort}")
  assertEquals "Failed to get pingdelegator pod port" 0 $?
  delegator_pod_port=$(echo "${delegator_pod_port}" | tr -s '[[:space:]]')

  # Test local connection with all Ping Delegated admin pods
  for pod_name in ${delegator_pod_names}
  do
    kubectl exec -it "${pod_name}" -n "${PING_CLOUD_NAMESPACE}" -- \
      curl -ssk -o /dev/null "https://localhost:${delegator_pod_port}/delegator"
    exit_code=$?

    assertEquals "The Ping Delegated Admin pod '${pod_name}:${delegator_pod_port}' connection is inaccessible." 0 $exit_code
  done
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}