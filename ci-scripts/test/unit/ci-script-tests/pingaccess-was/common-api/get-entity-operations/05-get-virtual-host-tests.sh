#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess-was/common-api/get-entity-operations.sh
. "${script_to_test}"

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/ci-script-tests/pingaccess-was/common-api/get-entity-operations/resources

# Mock this function call
curl() {
  get_virtual_host_200_response=$(cat "${resources_dir}"/get-virtual-host-200-response.txt)
  # echo into stdout as a return value
  echo "${get_virtual_host_200_response}"
  return 0
}

testGetVirtualHostHappyPath() {
  local http_ok_status_line='HTTP/1.1 200 OK'

  get_virtual_host_response=$(get_virtual_host "" "" "")
  assertEquals "The mocked curl function should force get_virtual_host to return 0." 0 $?
  assertContains "The get_virtual_host response \"${get_virtual_host_response}\" does not contain \"${http_ok_status_line}\"" "${get_virtual_host_response}" "${http_ok_status_line}"
}

# load shunit
. ${SHUNIT_PATH}