#!/bin/bash

script_to_test="${PROJECT_DIR}"/ci-scripts/test/integration/pingaccess/common-api/create-entity-operations.sh
. "${script_to_test}"

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/ci-script-tests/pingaccess/common-api/create-entity-operations/resources

# Mock this function call
curl() {
  create_agent_200_response=$(cat "${resources_dir}"/create-agent-200-response.txt)
  # echo into stdout as a return value
  echo "${create_agent_200_response}"
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

testCreateAgentHappyPath() {
  local http_ok_status_line='HTTP/1.1 200 OK'
  local name='"name":"agent1"'

  # curl is mocked above so these parameters don't matter
  create_agent_response=$(create_agent "" "")
  assertEquals "The function create_agent returned a non-zero exit code.  The mocked curl function should force create_agent to return 0." 0 $?
  assertContains "The create_agent response \"${create_agent_response}\" does not contain \"${http_ok_status_line}\"." "${create_agent_response}" "${http_ok_status_line}"
  assertContains "The create_agent response \"${create_agent_response}\" does not contain \"${name}\"." "${create_agent_response}" "${name}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
