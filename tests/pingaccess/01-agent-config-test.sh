#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {

  SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
  . ${SCRIPT_HOME}/common-api/create-entity-operations.sh
  . ${SCRIPT_HOME}/common-api/get-entity-operations.sh
  . ${SCRIPT_HOME}/common-api/delete-entity-operations.sh
  . ${SCRIPT_HOME}/runtime/send-request-to-agent-port.sh

  export PA_ADMIN_PASSWORD=2FederateM0re
  export templates_dir_path="${SCRIPT_HOME}/templates"
}

testAgentConfig() {

  agent_shared_secret='agent1sharedsecret1234'  # shared secrets must be 22 chars
  pa_engine_host='pingaccess'
  agent_name='agent1'

  # If the app exists, then delete it
  get_application_response=$(get_application_by_name "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" 'app1')
  application_id=$(parse_value_from_array_response "${get_application_response}" 'id')

  if [[ "${application_id}" != '' ]]; then
    log "Found an existing application. Deleting it..."
    delete_application_response=$(delete_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${application_id}")
    assertEquals "Failed to delete the application: ${delete_application_response}" 0 $?
  fi

  # If the agent exists, then delete it 
  get_agent_response=$(get_agent_by_name "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" 'agent1')
  agent_id=$(parse_value_from_array_response "${get_agent_response}" 'id')

  if [[ "${agent_id}" != '' ]]; then
    log "Found an existing agent. Deleting it..."
    # Remove the agent
    delete_agent_response=$(delete_agent "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_id}")
    assertEquals "Failed to delete the agent: ${delete_agent_response}" 0 $?
  fi

  # If the virtual host exists, delete it 
  get_virtual_host_response=$(get_virtual_host_by_host_port "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" '*%3A443')
  virtual_host_id=$(parse_value_from_array_response "${get_virtual_host_response}" 'id')

  if [[ "${virtual_host_id}" != '' ]]; then
    log "Found an existing virtual host. Deleting it..."
    delete_virtual_host_response=$(delete_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${virtual_host_id}")
    assertEquals "Failed to remove the virtual host with the virtual_host_id: ${virtual_host_id}.  The response was: ${delete_virtual_host_response}" 0 $?
  fi

  # Always create a shared secret
  create_shared_secret_response=$(create_shared_secret "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_shared_secret}")
  assertEquals "Failed to create a shared secret with POST request to: ${PINGACCESS_API} using admin password: ${PA_ADMIN_PASSWORD}.  The response was ${create_shared_secret_response}" 0 $?
  
  shared_secret_id=$(parse_value_from_response "${create_shared_secret_response}" 'id')
  assertEquals "Failed to parse the id from the shared secret response: ${create_shared_secret_response}" 0 $?

  # Create virtual host
  create_virtual_host_response=$(create_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}")
  assertEquals "Failed to create the virtual host with the response: ${create_virtual_host_response}" 0 $?

  virtual_host_id=$(parse_value_from_response "${create_virtual_host_response}" 'id')
  assertEquals "Failed to parse the id from the newly created virtual host" 0 $?

  # Create agent
  create_agent_response=$(create_agent "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" ${shared_secret_id} "${pa_engine_host}")
  assertEquals "Failed to create the agent with a shared secret id of ${shared_secret_id} with the response: ${create_agent_response}" 0 $?

  agent_id=$(parse_value_from_response "${create_agent_response}" 'id')
  assertEquals "Failed to parse the id from the agent response: ${create_agent_response}" 0 $?

  # Create application
  create_application_response=$(create_agent_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_id}" "${virtual_host_id}")
  assertEquals "Failed to create the application with a password of ${PA_ADMIN_PASSWORD}, an agent_id of ${agent_id} and a virtual_host_id of ${virtual_host_id}.  The response was: ${create_application_response}" 0 $?

  application_id=$(parse_value_from_response "${create_application_response}" 'id')
  assertEquals "Failed to parse the id from the application response" 0 $?

  # sleep 3 seconds to allow the config
  # to propagate to the engines
  sleep 3

  ### Use kubectl exec to connect to the ping-admin-0 instance and verify
  ### the agent port on pingaccess-0 is listening
  send_request_to_agent_port "${agent_name}" "${agent_shared_secret}" 'pingaccess-0' "${PING_CLOUD_NAMESPACE}"
  assertEquals "Failed to send a request to the pingaccess-0 runtime agent port for the agent: ${agent_name} with the shared secret: ${agent_shared_secret} in the namespace: ${PING_CLOUD_NAMESPACE}." 0 $?

  log "Request sent to the agent port on pingaccess-0 was successful"

  # Remove the app
  delete_application_response=$(delete_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${application_id}")
  assertEquals "Failed to remove the application app1 with the application_id: ${application_id}.  The response was: ${delete_application_response}" 0 $?

  # Remove the agent
  delete_agent_response=$(delete_agent "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_id}")
  assertEquals "Failed to remove the agent with the agent_id: ${agent_id}.  The response was: ${delete_agent_response}" 0 $?

  # Remove the virtual host
  delete_virtual_host_response=$(delete_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${virtual_host_id}")
  assertEquals "Failed to remove the virtual host with the virtual_host_id: ${virtual_host_id}.  The response was: ${delete_virtual_host_response}" 0 $?
}

tearDown() {
  # clean up global variables
  unset templates_dir_path
  unset PA_ADMIN_PASSWORD
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
