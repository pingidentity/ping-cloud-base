#!/bin/bash

# Suppress env vars noise in the test output
. "${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess/common-api/create-entity-operations.sh > /dev/null

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/ci-script-tests/pingaccess/common-api/create-entity-operations/resources

# Mock this function call
curl() {
  create_shared_secret_200_response=$(cat "${resources_dir}"/create-shared-secret-200-response.txt)
  # echo into stdout as a return value
  echo "${create_shared_secret_200_response}"
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

testCreateSharedSecretHappyPath() {
  local http_ok_status_line='HTTP/1.1 200 OK'
  local created='"created":1602776207157'

  # curl is mocked above so these parameters don't matter
  create_shared_secret_response=$(create_shared_secret "" "" "")
  assertEquals "The mocked curl function should force create_shared_secret to return 0." 0 $?
  assertContains "The create_shared_secret response \"${create_shared_secret_response}\" does not contain \"${http_ok_status_line}\"." "${create_shared_secret_response}" "${http_ok_status_line}"
  assertContains "The create_shared_secret response \"${create_shared_secret_response}\" does not contain \"${created}\"." "${create_shared_secret_response}" "${created}"
}

# load shunit
. ${SHUNIT_PATH}