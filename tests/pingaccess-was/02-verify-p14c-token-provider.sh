#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {

  # Using the pa-test-utils in the pingaccess
  # directory to avoid duplication.
  . ${PROJECT_DIR}/tests/pingaccess/util/pa-test-utils.sh

  SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
  . ${SCRIPT_HOME}/common-api/get-entity-operations.sh

  export PA_ADMIN_PASSWORD=2FederateM0re
}

testP14cCredentialsAdded() {
  local response=$(get_ping_one "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}")

  local issuer=$(parse_value_from_response "${response}" 'issuer')
  assertNotEquals 'null' "${issuer}"
}

testP14cSetAsTokenProvider() {
  local response=$(get_token_provider "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}")

  local token_provider=$(parse_value_from_response "${response}" 'type')
  assertEquals 'PingOneForCustomers' $(strip_double_quotes ${token_provider})
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}