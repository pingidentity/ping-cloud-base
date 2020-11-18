#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess-was/common-api/get-entity-operations.sh
. "${script_to_test}"

# Mock this function call
curl() {
  # Mocking a 'couldn't resolve host' error 6
  return 6
}

testGetTokenProviderWithBadCurlResponse() {
  local mock_hostname='https://mock-hostname'
  local mock_endpoint=${mock_hostname}'/tokenProvider/settings'
  local error_msg="ERROR: The curl call to ${mock_endpoint} returned the exit code: 6"

  get_token_provider_response=$(get_token_provider "" "${mock_hostname}")
  assertEquals "The function get_token_provider returned an exit code other than 6.  The mocked curl function should force get_token_provider to return 6." 6 $?
  assertContains "The get_token_provider response \"${get_token_provider_response}\" does not contain \"${error_msg}\"." "${get_token_provider_response}" "${error_msg}"
}

# load shunit
. ${SHUNIT_PATH}