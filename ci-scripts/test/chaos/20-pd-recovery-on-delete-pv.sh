#!/bin/bash -x

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

########################################################################################################################
# Wait for the expected topology master instance name.
#
# Arguments
#   ${1} -> The expected master instance name.
#   ${2} -> Wait timeout in seconds. Default is 10 minutes.
########################################################################################################################
wait_for_expected_topology_master() {
  EXPECTED_MASTER="${1}"
  TIMEOUT_SECONDS=${2:-600}

  TIME_WAITED_SECONDS=0
  SLEEP_SECONDS=10

  while true; do
    TOPOLOGY_STATUS=$(kubectl exec pingdirectory-0 \
        -c pingdirectory -n "${NAMESPACE}" -- status | grep '^cn=Topology,cn=config')
    echo "${TOPOLOGY_STATUS}" | grep -q "${EXPECTED_MASTER}" &> /dev/null
    test $? -eq 0 && return 0

    sleep "${SLEEP_SECONDS}"
    TIME_WAITED_SECONDS=$((TIME_WAITED_SECONDS + SLEEP_SECONDS))

    if test "${TIME_WAITED_SECONDS}" -ge "${TIMEOUT_SECONDS}"; then
      echo "Expected master ${EXPECTED_MASTER} but found '${TOPOLOGY_STATUS}' after ${TIMEOUT_SECONDS} seconds"
      return 1
    fi
  done
}

# This is a contrived test for PDO-988. See issue for more details.
PD_REPLICA_SET='statefulset.apps/pingdirectory'

GET_REPLICAS_COMMAND="kubectl get ${PD_REPLICA_SET} -o jsonpath='{.status.readyReplicas}' -n ${NAMESPACE}"
GET_PVC_COMMAND="kubectl get pvc -n ${NAMESPACE} -o name | grep -c out-dir-pingdirectory"

# Verify that there are 2 replicas to begin.
CURRENT_NUM_REPLICAS=$(eval "${GET_REPLICAS_COMMAND}")
test "${CURRENT_NUM_REPLICAS}" -ne 2 && exit 1

# Get rid of the pre-stop hook script from pingdirectory-1 so it is not removed from the PD replication topology.
kubectl exec pingdirectory-1 -c pingdirectory -n "${NAMESPACE}" -- rm -f /opt/staging/hooks/86-pre-stop.sh

# Scale down to 1 replica and wait for the number of replicas in ready state to go down to 1.
kubectl scale --replicas=1 ${PD_REPLICA_SET} -n "${NAMESPACE}"
wait_for_expected_resource_count 1 "${GET_REPLICAS_COMMAND}" 120
test $? -ne 0 && exit 1

# Remove pingdirectory-1's PVC and verify that there is only one PVC.
kubectl delete pvc -n "${NAMESPACE}" out-dir-pingdirectory-1
wait_for_expected_resource_count 1 "${GET_PVC_COMMAND}" 120
test $? -ne 0 && exit 1

# Topology should have no master, i.e. read-only.
wait_for_expected_topology_master 'No Master (data read-only)' 10
test $? -ne 0 && exit 1

# Scale back up to 2 replicas and wait for the number of replicas in ready state to go up to 2.
kubectl scale --replicas=2 "${PD_REPLICA_SET}" -n "${NAMESPACE}"
wait_for_expected_resource_count 2 "${GET_REPLICAS_COMMAND}" 600
test $? -ne 0 && exit 1

# Verify that the topology has a master. This will take a while because post-start is run in the background after the
# pod is Ready.
wait_for_expected_topology_master 'pingdirectory-0' 600
exit $?