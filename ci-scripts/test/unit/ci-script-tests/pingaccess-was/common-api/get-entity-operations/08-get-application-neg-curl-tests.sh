#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess-was/common-api/get-entity-operations.sh
. "${script_to_test}"

# Mock this function call
curl() {
  # Mocking a 'couldn't resolve host' error 6
  return 6
}

testGetApplicationWithBadCurlResponse() {
  local mock_hostname='https://mock-hostname'
  local mock_endpoint=${mock_hostname}'/applications/1'
  local error_msg="ERROR: The curl call to ${mock_endpoint} returned the exit code: 6"

  get_application_response=$(get_application "" "${mock_hostname}" "1")
  assertEquals "The function get_application returned an exit code other than 6.  The mocked curl function should force get_application to return 6." 6 $?
  assertContains "The get_application response \"${get_application_response}\" does not contain \"${error_msg}\"." "${get_application_response}" "${error_msg}"
}

# load shunit
. ${SHUNIT_PATH}