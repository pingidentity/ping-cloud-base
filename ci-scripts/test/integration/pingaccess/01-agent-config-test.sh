#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

setUp() {

  SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
  . ${SCRIPT_HOME}/util/pa-test-utils
  . ${SCRIPT_HOME}/common-api/create-entity-operations
  . ${SCRIPT_HOME}/common-api/get-entity-operations
  . ${SCRIPT_HOME}/common-api/delete-entity-operations
  . ${SCRIPT_HOME}/runtime/send-request-to-agent-port
}

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testAgentConfig() {


  export templates_dir_path=${SCRIPT_HOME}/templates

  PA_ADMIN_PASSWORD=2FederateM0re
  agent_shared_secret='agent1sharedsecret1234'  # shared secrets must be 22 chars

  pa_engine_host='pingaccess'
  agent_name='agent1'

  # Create a shared secret
  create_shared_secret_response=$(create_shared_secret "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_shared_secret}")
  [ $? -ne 0 ] && exit 1

  shared_secret_id=$(parse_value_from_response "${create_shared_secret_response}" 'id')

  # Check to see if the virtual host exists using search criteria of *:443
  get_virtual_host_response=$(get_virtual_host_by_host_port "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" '*%3A443')

  virtual_host_hostname=$(parse_value_from_array_response "${get_virtual_host_response}" 'host')
  virtual_host_port=$(parse_value_from_array_response "${get_virtual_host_response}" 'port')
  virtual_host_id=$(parse_value_from_array_response "${get_virtual_host_response}" 'id')

  if [[ "${virtual_host_hostname}" != '*' && ${virtual_host_port} -ne 443 ]]; then

    log 'The virtual host *:443 does not exist.  Creating it...'

    # Create a virtual host
    create_virtual_host_response=$(create_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}")
    [ $? -ne 0 ] && exit 1

    virtual_host_id=$(parse_value_from_response "${create_virtual_host_response}" 'id')

    else
      log 'The virtual host *:443 already exists.'
  fi


  # Check if the application got orphaned on a previous run
  get_application_response=$(get_application_by_name "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" 'app1')

  # If the app exists, then delete it
  application_id=$(parse_value_from_array_response "${get_application_response}" 'id')
  if [[ "${application_id}" != '' ]]; then

    log "Found an existing application.  Deleting it..."

    # Remove the app
    delete_application_response=$(delete_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${application_id}")
    [ $? -ne 0 ] && exit 1
  fi


  # Check if the agent got orphaned on a previous run
  get_agent_response=$(get_agent_by_name "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" 'agent1')

  # If the agent exists, then delete it
  agent_id=$(parse_value_from_array_response "${get_agent_response}" 'id')
  if [[ "${agent_id}" != '' ]]; then

    log "Found an existing agent.  Deleting it..."

    # Remove the agent
    delete_agent_response=$(delete_agent "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_id}")
    [ $? -ne 0 ] && exit 1
  fi

  # Create an agent
  create_agent_response=$(create_agent "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" ${shared_secret_id} "${pa_engine_host}")
  [ $? -ne 0 ] && exit 1

  agent_id=$(parse_value_from_response "${create_agent_response}" 'id')

  # Create an app
  create_application_response=$(create_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_id}" "${virtual_host_id}")
  [ $? -ne 0 ] && exit 1

  application_id=$(parse_value_from_response "${create_application_response}" 'id')

  # sleep 3 seconds to allow the config
  # to propagate to the engines
  sleep 3


  ### Use kubectl exec to connect to the ping-admin-0 instance and verify
  ### the agent port on pingaccess-0 is listening
  agent_port_runtime_response=$(send_request_to_agent_port "${agent_name}" "${agent_shared_secret}" 'pingaccess-0' "${NAMESPACE}")
  [ $? -ne 0 ] && exit 1

  log "Request sent to the agent port on pingaccess-0 was successful"

  ### Use kubectl exec to connect to the ping-admin-0 instance and verify
  ### the agent port on pingaccess-1 is listening
  agent_port_runtime_response=$(send_request_to_agent_port "${agent_name}" "${agent_shared_secret}" 'pingaccess-1' "${NAMESPACE}")
  [ $? -ne 0 ] && exit 1

  log "Request sent to the agent port on pingaccess-1 was successful"

  # Remove the app
  delete_application_response=$(delete_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${application_id}")
  [ $? -ne 0 ] && exit 1


  # Remove the agent
  delete_agent_response=$(delete_agent "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_id}")
  [ $? -ne 0 ] && exit 1


  # Remove the virtual host
  delete_virtual_host_response=$(delete_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${virtual_host_id}")
  [ $? -ne 0 ] && exit 1

  assertEquals 0 0
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
