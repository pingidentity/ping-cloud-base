#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

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

  # Create a shared secret
  create_shared_secret_response=$(create_shared_secret "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_shared_secret}")
  return_code=$?
  assertEquals "Failed to create a shared secret with POST request to: ${PINGACCESS_API} using admin password: ${PA_ADMIN_PASSWORD}.  The response was ${create_shared_secret_response}" 0 ${return_code}

  shared_secret_id=$(parse_value_from_response "${create_shared_secret_response}" 'id')
  assertEquals "Failed to parse the id from the shared secret response: ${create_shared_secret_response}" 0 $?

  # Check to see if the virtual host exists using search criteria of *:443
  get_virtual_host_response=$(get_virtual_host_by_host_port "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" '*%3A443')
  assertEquals "Failed to get the virtual host.  The response was ${get_virtual_host_response}" 0 $?

  virtual_host_hostname=$(parse_value_from_array_response "${get_virtual_host_response}" 'host')
  assertEquals "Failed to parse the host from the virtual host response: ${get_virtual_host_response}" 0 $?

  virtual_host_port=$(parse_value_from_array_response "${get_virtual_host_response}" 'port')
  assertEquals "Failed to parse the port from the virtual host response: ${get_virtual_host_response}" 0 $?

  virtual_host_id=$(parse_value_from_array_response "${get_virtual_host_response}" 'id')
  assertEquals "Failed to parse the id from the virtual host response: ${get_virtual_host_response}" 0 $?

  if [[ "${virtual_host_hostname}" != '*' && ${virtual_host_port} -ne 443 ]]; then

    log 'The virtual host *:443 does not exist.  Creating it...'

    # Create a virtual host
    create_virtual_host_response=$(create_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}")
    assertEquals "Failed to create the virtual host with the response: ${create_virtual_host_response}" 0 $?

    virtual_host_id=$(parse_value_from_response "${create_virtual_host_response}" 'id')
    assertEquals "Failed to parse the id from the newly created virtual host" 0 $?

  else
    log 'The virtual host *:443 already exists.'
  fi


  # Check if the application got orphaned on a previous run
  get_application_response=$(get_application_by_name "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" 'app1')
  assertEquals "Failed to GET the application app1 by name" 0 $?

  # If the app exists, then delete it
  application_id=$(parse_value_from_array_response "${get_application_response}" 'id')
  if [[ "${application_id}" != '' ]]; then

    log "Found an existing application.  Deleting it..."

    # Remove the app
    delete_application_response=$(delete_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${application_id}")
    assertEquals "Failed to delete the application" 0 $?

  fi


  # Check if the agent got orphaned on a previous run
  get_agent_response=$(get_agent_by_name "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" 'agent1')
  assertEquals "Failed to GET the agent agent1 by name" 0 $?

  # If the agent exists, then delete it
  agent_id=$(parse_value_from_array_response "${get_agent_response}" 'id')
  assertEquals "Failed to parse the id from the agent response" 0 $?

  if [[ "${agent_id}" != '' ]]; then

    log "Found an existing agent.  Deleting it..."

    # Remove the agent
    delete_agent_response=$(delete_agent "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_id}")
    assertEquals "Failed to delete the agent: ${delete_agent_response}" 0 $?
  fi

  # Create an agent
  create_agent_response=$(create_agent "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" ${shared_secret_id} "${pa_engine_host}")
  assertEquals "Failed to create the agent with a shared secret id of ${shared_secret_id} with the response: ${create_agent_response}" 0 $?

  agent_id=$(parse_value_from_response "${create_agent_response}" 'id')
  assertEquals "Failed to parse the id from the agent response: ${create_agent_response}" 0 $?

  # Create an app
  create_application_response=$(create_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_id}" "${virtual_host_id}")
  assertEquals "Failed to create the application with a password of ${PA_ADMIN_PASSWORD}, an agent_id of ${agent_id} and a virtual_host_id of ${virtual_host_id}.  The response was: ${create_application_response}" 0 $?

  application_id=$(parse_value_from_response "${create_application_response}" 'id')
  assertEquals "Failed to parse the id from the application response" 0 $?

  # sleep 3 seconds to allow the config
  # to propagate to the engines
  sleep 3


  ### Use kubectl exec to connect to the ping-admin-0 instance and verify
  ### the agent port on pingaccess-0 is listening
  send_request_to_agent_port "${agent_name}" "${agent_shared_secret}" 'pingaccess-0' "${NAMESPACE}"
  assertEquals "Failed to send a request to the pingaccess-0 runtime agent port for the agent: ${agent_name} with the shared secret: ${agent_shared_secret} in the namespace: ${NAMESPACE}." 0 $?

  log "Request sent to the agent port on pingaccess-0 was successful"

  # Remove the app
  delete_application_response=$(delete_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${application_id}")
  return_code=$?
  assertEquals "Failed to remove the application app1 with the application_id: ${application_id}.  The response was: ${delete_application_response}" 0 ${return_code}

  # Remove the agent
  delete_agent_response=$(delete_agent "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_id}")
  return_code=$?
  assertEquals "Failed to remove the agent with the agent_id: ${agent_id}.  The response was: ${delete_agent_response}" 0 ${return_code}

  # Remove the virtual host
  delete_virtual_host_response=$(delete_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${virtual_host_id}")
  return_code=$?
  assertEquals "Failed to remove the virtual host with the virtual_host_id: ${virtual_host_id}.  The response was: ${delete_virtual_host_response}" 0 ${return_code}
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
