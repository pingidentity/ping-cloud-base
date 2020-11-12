#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess/common-api/create-entity-operations.sh
. "${script_to_test}"

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/ci-script-tests/pingaccess/common-api/create-entity-operations/resources

# Mock this function call
curl() {
  create_agent_422_response=$(cat "${resources_dir}"/create-agent-422-response.txt)
  # echo into stdout as a return value
  echo "${create_agent_422_response}"
  return 0
}

setUp() {
  # templates_dir_path must be exported into the env
  # for create_agent to find the json file
  # it needs.
  export templates_dir_path="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess/templates
}

oneTimeTearDown() {
  unset templates_dir_path
}

testCreateAgentNegCase422Response() {
  local http_422='HTTP/1.1 422 Unprocessable Entity'
  local failed="Agent with id '1' already exists"

  # curl is mocked above so these parameters don't matter
  create_agent_response=$(create_agent "" "")
  assertEquals "The function create_agent returned an exit code other than 1.  The mocked curl function should force create_agent to return 1." 1 $?
  assertContains "The create_agent response \"${create_agent_response}\" does contain \"${failed}\"." "${create_agent_response}" "${failed}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}