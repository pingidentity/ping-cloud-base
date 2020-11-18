#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess/common-api/create-entity-operations.sh
. "${script_to_test}"


readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/ci-script-tests/pingaccess/common-api/create-entity-operations/resources

# Mock this function call
curl() {
  create_shared_secret_422_response=$(cat "${resources_dir}"/create-shared-secret-422-response.txt)
  # echo into stdout as a return value
  echo "${create_shared_secret_422_response}"
  return 0
}

setUp() {
  # templates_dir_path must be exported into the env
  # for create_shared_secret to find the json file
  # it needs.
  export templates_dir_path="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess/templates
}

oneTimeTearDown() {
  unset templates_dir_path
}

testCreateSharedSecretNegCase422Response() {
  local http_422='HTTP/1.1 422 Unprocessable Entity'
  local failed='Failed to add a new Shared Secret'

  # curl is mocked above so these parameters don't matter
  create_shared_secret_response=$(create_shared_secret "" "" "")
  assertEquals "The function create_shared_secret returned an exit code other than 1.  The mocked curl function should force create_shared_secret to return 1." 1 $?
  assertContains "The create_shared_secret response should contain \"${http_422}\"" "${create_shared_secret_response}" "${http_ok}"
  assertContains "The create_shared_secret response should contain \"${failed}\"." "${create_shared_secret_response}" "${created}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
