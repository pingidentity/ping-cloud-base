#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# This is a contrived test for PDO-988. See issue for more details.
PD_REPLICA_SET='statefulset.apps/pingdirectory'

GET_REPLICAS_COMMAND="kubectl get ${PD_REPLICA_SET} -o jsonpath='{.status.readyReplicas}' -n ${NAMESPACE}"
GET_PVC_COMMAND="kubectl get pvc -n ${NAMESPACE} -o name | grep -c out-dir-pingdirectory"

GET_NUM_PEERS_COMMAND="kubectl exec pingdirectory-0 -c pingdirectory -n ${NAMESPACE} -- \\
    ldapsearch --terse --baseDN 'cn=monitor' --searchScope sub \\
    '&(objectClass=ds-mirrored-subtree-monitor-entry)(subtree-base-dn=cn=Topology,cn=config)' \\
    num-peers | grep '^num-peers' | cut -d' ' -f2"
GET_UNAVAILABLE_PEERS_COMMAND="kubectl exec pingdirectory-0 -c pingdirectory -n ${NAMESPACE} -- \\
    ldapsearch --terse --baseDN 'cn=monitor' --searchScope sub \\
    '&(objectClass=ds-mirrored-subtree-monitor-entry)(subtree-base-dn=cn=Topology,cn=config)' \\
    unavailable-peer-count | grep '^unavailable-peer-count' | cut -d' ' -f2"

# Verify that there are 2 replicas to begin.
log "Verifying that there are 2 PD replicas running"
wait_for_expected_resource_count 2 "${GET_REPLICAS_COMMAND}" 300
test $? -ne 0 && exit 1

# Verify that there is 1 peer server of pingdirectory-0 in the PD replication topology.
log "Verifying that there is 1 peer of server 0 in the topology"
wait_for_expected_resource_count 1 "${GET_NUM_PEERS_COMMAND}" 300
test $? -ne 0 && exit 1

# Verify that there are 0 unavailable peers.
log "Verifying that there are no unavailable peers in the topology"
wait_for_expected_resource_count 0 "${GET_UNAVAILABLE_PEERS_COMMAND}" 300
test $? -ne 0 && exit 1

# Get rid of the pre-stop hook script from pingdirectory-1 so it is not removed from the PD replication topology.
log "Verify that the pre-stop hook is present on pingdirectory-1"
FILE_COUNT=$(kubectl exec pingdirectory-1 -c pingdirectory -n "${NAMESPACE}" -- \
    ls /opt/staging/hooks/86-pre-stop.sh 2> /dev/null | wc -l)
test "${FILE_COUNT}" -ne 1 && exit 1

log "Removing pre-stop hook from pingdirectory-1"
kubectl exec pingdirectory-1 -c pingdirectory -n "${NAMESPACE}" -- rm -f /opt/staging/hooks/86-pre-stop.sh

log "Verify that the pre-stop hook is gone from pingdirectory-1"
FILE_COUNT=$(kubectl exec pingdirectory-1 -c pingdirectory -n "${NAMESPACE}" -- \
    ls /opt/staging/hooks/86-pre-stop.sh 2> /dev/null | wc -l)
test "${FILE_COUNT}" -ne 0 && exit 1

# Scale down to 1 replica and wait for the number of replicas in ready state to go down to 1.
log "Scaling down pingdirectory replica set to 1"
kubectl scale --replicas=1 ${PD_REPLICA_SET} -n "${NAMESPACE}"

log "Verifying that there's just 1 replica after scale-down"
wait_for_expected_resource_count 1 "${GET_REPLICAS_COMMAND}" 120
test $? -ne 0 && exit 1

# Remove pingdirectory-1's PVC and verify that there is only one PVC.
log "Removing pingdirectory-1 PVC"
kubectl delete pvc -n "${NAMESPACE}" out-dir-pingdirectory-1

log "Verifying that there's just 1 PVC after deleting the other"
wait_for_expected_resource_count 1 "${GET_PVC_COMMAND}" 300
test $? -ne 0 && exit 1

# There should be one unavailable peer.
log "Verifying that there's 1 unavailable peer in the topology"
wait_for_expected_resource_count 1 "${GET_UNAVAILABLE_PEERS_COMMAND}" 300
test $? -ne 0 && exit 1

# Scale back up to 2 replicas and wait for the number of replicas in ready state to go up to 2.
log "Scaling up pingdirectory replica set to 2"
kubectl scale --replicas=2 "${PD_REPLICA_SET}" -n "${NAMESPACE}"

log "Verifying that there's 2 replicas after scale-up"
wait_for_expected_resource_count 2 "${GET_REPLICAS_COMMAND}" 900
test $? -ne 0 && exit 1

# There should be no unavailable peers.
log "Verifying that there's 0 unavailable peers in the topology"
wait_for_expected_resource_count 0 "${GET_UNAVAILABLE_PEERS_COMMAND}" 900
exit $?