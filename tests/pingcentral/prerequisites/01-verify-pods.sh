#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPodConnection() {

  expected_ready_state="1/1"
  pod_label_name="role=pingcentral"

  # Get pingcentral pod name
  pingcentral_pod_name=$(kubectl get pods \
                          -l "${pod_label_name}" \
                          -n "${PING_CLOUD_NAMESPACE}" \
                          -o=jsonpath="{.items[*].metadata.name}" | tr -s '[[:space:]]')
  pingcentral_ready_state=$(kubectl get pods "${pingcentral_pod_name}" \
                            -n "${PING_CLOUD_NAMESPACE}" | tail -n +2 | awk '{print $2}' | tr -s '[[:space:]]')
  assertEquals "Failed to get pingcentral running state 1/1" "${expected_ready_state}" "${pingcentral_ready_state}"
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}