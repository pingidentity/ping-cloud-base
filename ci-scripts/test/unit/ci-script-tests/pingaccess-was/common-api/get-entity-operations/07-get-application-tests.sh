#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess-was/common-api/get-entity-operations.sh
. "${script_to_test}"

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/ci-script-tests/pingaccess-was/common-api/get-entity-operations/resources

# Mock this function call
curl() {
  get_application_200_response=$(cat "${resources_dir}"/get-application-200-response.txt)
  # echo into stdout as a return value
  echo "${get_application_200_response}"
  return 0
}

testGetApplicationHappyPath() {
  local http_ok_status_line='HTTP/1.1 200 OK'

  get_application_response=$(get_application "" "" "")
  assertEquals "The mocked curl function should force get_application_response to return 0." 0 $?
  assertContains "The get_application response \"${get_application_response}\" does not contain \"${http_ok_status_line}\"" "${get_application_response}" "${http_ok_status_line}"
}

# load shunit
. ${SHUNIT_PATH}