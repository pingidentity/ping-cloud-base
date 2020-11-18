#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess-was/common-api/get-entity-operations.sh
. "${script_to_test}"

# Mock this function call
curl() {
  # Mocking a 'couldn't resolve host' error 6
  return 6
}

testGetEntityWithBadCurlResponse() {
  local mock_hostname='https://mock-hostname'
  local mock_endpoint=${mock_hostname}'/applications/reserved'
  local error_msg="ERROR: The curl call to ${mock_endpoint} returned the exit code: 6"

  get_entity_response=$(get_entity "" "${mock_endpoint}" "")
  assertEquals "The function get_entity returned an exit code other than 6.  The mocked curl function should force get_entity to return 6." 6 $?
  assertContains "The get_entity response \"${get_entity_response}\" does not contain \"${error_msg}\"." "${get_entity_response}" "${error_msg}"
}

# load shunit
. ${SHUNIT_PATH}