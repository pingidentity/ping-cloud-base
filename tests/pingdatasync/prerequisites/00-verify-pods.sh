#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPodConnection() {

  expected_ready_state="1/1"

  pingdatasync_ready_state=$(kubectl get pods "pingdatasync-0" \
                            -n "${PING_CLOUD_NAMESPACE}" | tail -n +2 | awk '{print $2}' | tr -s '[[:space:]]')
  assertEquals "Failed to get pingdatasync running state 1/1" "${expected_ready_state}" "${pingdatasync_ready_state}"
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}