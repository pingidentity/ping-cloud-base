#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess/common-api/log-response.sh
. "${script_to_test}"


message="There was a problem"

testLogResponseWithInput200() {
  response="Some response value"
  log_response=$(log_response 200 "${response}" "${message}")

  assertEquals "The function log_response should have returned 0 given an input of 200." 0 $?
  assertSame "The function log_response response should be \"${response}\" but instead it was \"${log_response}\"" "${response}" "${log_response}"
}

testLogResponseWithInput422() {
  log_response=$(log_response 422 "HTTP Unprocessable Entity" "${message}")

  assertEquals "The function log_response should have returned 1 given an input of 422." 1 $?
  assertContains "The function log_response response should contain \"${message}\" but instead it was \"${log_response}\"" "${log_response}" "${message}"
}

# load shunit
. ${SHUNIT_PATH}