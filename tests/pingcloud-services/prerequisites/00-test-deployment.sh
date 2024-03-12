#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"
. "${CI_SCRIPTS_DIR}"/test/test_utils.sh

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testP14CBootstrapDeploymentAvailability() {
  resource_name="p14c-bootstrap"
  resource_kind="deployment"
  verify_resource_with_sleep "${resource_kind}" "${PING_CLOUD_NAMESPACE}" "${resource_name}"
  status=$?

  assertEquals "The Available status of the p14c-bootstrap deployment should be 0 but was: ${status}" 0 ${status}
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}