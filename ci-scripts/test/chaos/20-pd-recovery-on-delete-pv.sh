#!/bin/bash -x

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

# This is a contrived test for PDO-988. See issue for more details.
PD_REPLICA_SET='statefulset.apps/pingdirectory'

GET_REPLICAS_COMMAND="kubectl get ${PD_REPLICA_SET} -o jsonpath='{.status.readyReplicas}' -n ${NAMESPACE}"
GET_PVC_COMMAND="kubectl get pvc -n ${NAMESPACE} -o name | grep -c out-dir-pingdirectory"
GET_UNAVAILABLE_PEERS_COMMAND="kubectl exec pingdirectory-0 -c pingdirectory -n ${NAMESPACE} -- \\
    ldapsearch --terse --baseDN 'cn=monitor' --searchScope sub \\
    '&(objectClass=ds-mirrored-subtree-monitor-entry)(subtree-base-dn=cn=Topology,cn=config)' \\
    unavailable-peer-count | grep '^unavailable-peer-count' | cut -d' ' -f2"

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

# There should be one unavailable peer.
wait_for_expected_resource_count 1 "${GET_UNAVAILABLE_PEERS_COMMAND}" 300
test $? -ne 0 && exit 1

# Scale back up to 2 replicas and wait for the number of replicas in ready state to go up to 2.
kubectl scale --replicas=2 "${PD_REPLICA_SET}" -n "${NAMESPACE}"
wait_for_expected_resource_count 2 "${GET_REPLICAS_COMMAND}" 900
test $? -ne 0 && exit 1

# There should be no unavailable peers.
wait_for_expected_resource_count 0 "${GET_UNAVAILABLE_PEERS_COMMAND}" 900
exit $?