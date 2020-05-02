#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

. ${SCRIPT_HOME}/util/pa_test_utils
. ${SCRIPT_HOME}/common_api/create-entity-operations
. ${SCRIPT_HOME}/common_api/delete-entity-operations
. ${SCRIPT_HOME}/runtime/send-request-to-agent-port

export templates_dir_path=${SCRIPT_HOME}/templates

PA_ADMIN_PASSWORD=2FederateM0re
agent_shared_secret='agent1sharedsecret1234'  # shared secrets must be 22 chars

pa_engine_host='pingaccess'
agent_name='agent1'

echo ">>>> Starting ${0} test..."
set +x

# Create a shared secret
create_shared_secret_response=$(create_shared_secret "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_shared_secret}")
[ $? -ne 0 ] && exit 1

shared_secret_id=$(parse_value_from_response "${create_shared_secret_response}" 'id')

# Create a virtual host
create_virtual_host_response=$(create_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}")
[ $? -ne 0 ] && exit 1

virtual_host_id=$(parse_value_from_response "${create_virtual_host_response}" 'id')

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

set -x
echo "Request sent to the agent port on pingaccess-0 was successful"

set +x

### Use kubectl exec to connect to the ping-admin-0 instance and verify
### the agent port on pingaccess-1 is listening
agent_port_runtime_response=$(send_request_to_agent_port "${agent_name}" "${agent_shared_secret}" 'pingaccess-1' "${NAMESPACE}")
[ $? -ne 0 ] && exit 1

set -x
echo "Request sent to the agent port on pingaccess-1 was successful"

set +x


# Remove the app
delete_application_response=$(delete_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${application_id}")
[ $? -ne 0 ] && exit 1


# Remove the agent
delete_agent_response=$(delete_agent "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_id}")
[ $? -ne 0 ] && exit 1


# Remove the virtual host
delete_virtual_host_response=$(delete_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${virtual_host_id}")
[ $? -ne 0 ] && exit 1

set -x

echo ">>>> ${0} finished..."
