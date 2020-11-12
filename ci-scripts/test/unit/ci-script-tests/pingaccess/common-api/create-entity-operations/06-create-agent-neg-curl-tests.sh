#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess/common-api/create-entity-operations.sh
. "${script_to_test}"

# Mock this function call
curl() {
  # Mocking a 'couldn't resolve host' error 6
  return 6
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

testCreateAgentWithBadCurlResponse() {
  local mock_hostname='https://mock-hostname'
  local mock_endpoint=${mock_hostname}'/agents'
  local error_msg="ERROR: The curl call to ${mock_endpoint} returned the exit code: 6"

  create_agent_response=$(create_agent "" "${mock_hostname}" "" "")
  assertEquals "The function create_agent returned an exit code other than 6.  The mocked curl function should force create_agent to return 6." 6 $?
  assertContains "The create_agent response \"${create_agent_response}\" does not contain \"${error_msg}\"." "${create_agent_response}" "${error_msg}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
