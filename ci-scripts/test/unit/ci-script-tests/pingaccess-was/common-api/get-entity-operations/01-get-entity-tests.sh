#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess-was/common-api/get-entity-operations.sh
. "${script_to_test}"

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/ci-script-tests/pingaccess-was/common-api/get-entity-operations/resources

# Mock this function call
curl() {
  get_app_reserved_200_response=$(cat "${resources_dir}"/get-app-reserved-200-response.txt)
  # echo into stdout as a return value
  echo "${get_app_reserved_200_response}"
  return 0
}

testGetEntityHappyPath() {
  local http_ok_status_line='HTTP/1.1 200 OK'

  get_entity_response=$(get_entity "" "")
  assertEquals "The mocked curl function should force get_entity to return 0." 0 $?
  assertContains "The get_entity response \"${get_entity_response}\" does not contain \"${http_ok_status_line}\"" "${get_entity_response}" "${http_ok_status_line}"
}

# load shunit
. ${SHUNIT_PATH}