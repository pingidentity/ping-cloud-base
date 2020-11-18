#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess-was/common-api/get-entity-operations.sh
. "${script_to_test}"

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/ci-script-tests/pingaccess-was/common-api/get-entity-operations/resources

# Mock this function call
curl() {
  get_site_200_response=$(cat "${resources_dir}"/get-site-200-response.txt)
  # echo into stdout as a return value
  echo "${get_site_200_response}"
  return 0
}

testGetSiteHappyPath() {
  local http_ok_status_line='HTTP/1.1 200 OK'

  get_site_response=$(get_site "" "" "")
  assertEquals "The mocked curl function should force get_site to return 0." 0 $?
  assertContains "The get_site response \"${get_site_response}\" does not contain \"${http_ok_status_line}\"" "${get_site_response}" "${http_ok_status_line}"
}

# load shunit
. ${SHUNIT_PATH}