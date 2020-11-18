#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess/util/pa-test-utils.sh
. "${script_to_test}"

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/ci-script-tests/pingaccess/util/pa-test-utils/resources

testParseHttpResponseCode() {

  local four_twenty_curl_response=$(cat "${resources_dir}"/422-curl-http-response.txt)
  response_code=$(parse_http_response_code "${four_twenty_curl_response}")
  exit_code=$?

  assertEquals "The function parse_http_response_code returned a non-zero exit code when passed the input text \"${four_twenty_curl_response}\"." 0 ${exit_code}
  assertEquals "The function parse_http_response_code did not return an expected 422 response code when passed the input text \"${four_twenty_curl_response}\"." 422 ${response_code}
}

testParseValueFromResponse() {

  local two_hundred_curl_resp=$(cat "${resources_dir}"/200-curl-http-response.txt)
  value=$(parse_value_from_response "${two_hundred_curl_resp}" 'name')
  exit_code=$?

  assertEquals 0 ${exit_code}
  assertEquals "\"east\"" "${value}"
}

testParseValueFromArrayResponse() {

  local two_hundred_curl_array_resp=$(cat "${resources_dir}"/200-curl-http-response-json-array.txt)
  value=$(parse_value_from_array_response "${two_hundred_curl_array_resp}" 'name')
  exit_code=$?

  assertEquals 0 ${exit_code}
  assertEquals "\"app\"" "${value}"
}

# load shunit
. ${SHUNIT_PATH}
