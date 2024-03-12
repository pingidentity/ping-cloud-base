#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"
. "${CI_SCRIPTS_DIR}"/test/test_utils.sh

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

. "${PROJECT_DIR}"/tests/pingaccess-was/runtime/send-request-to-runtime-port.sh

testVerifyPAEngines() {
  resource_name="pingaccess-was"
  resource_kind="statefulset"
  verify_resource_with_sleep "${resource_kind}" "${PING_CLOUD_NAMESPACE}" "${resource_name}"
  assertEquals 0 $?
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}