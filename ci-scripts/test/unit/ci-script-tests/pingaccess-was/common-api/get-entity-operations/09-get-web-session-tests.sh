#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess-was/common-api/get-entity-operations.sh
. "${script_to_test}"

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/ci-script-tests/pingaccess-was/common-api/get-entity-operations/resources

# Mock this function call
curl() {
  get_web_session_200_response=$(cat "${resources_dir}"/get-web-session-200-response.txt)
  # echo into stdout as a return value
  echo "${get_web_session_200_response}"
  return 0
}

testGetWebSessionHappyPath() {
  local http_ok_status_line='HTTP/1.1 200 OK'

  get_web_session_response=$(get_web_session "" "" "")
  assertEquals "The mocked curl function should force get_web_session to return 0." 0 $?
  assertContains "The get_web_session response \"${get_web_session_response}\" does not contain \"${http_ok_status_line}\"" "${get_web_session_response}" "${http_ok_status_line}"
}

# load shunit
. ${SHUNIT_PATH}