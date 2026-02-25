#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}/common.sh" "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

scaleUpPDReplicas() {
  log "Scaling up pingdirectory replicas to ${1}"
  kubectl scale --replicas=${1} statefulset/pingdirectory -n "${PING_CLOUD_NAMESPACE}"
  assertTrue "kubectl scale command failed" $?
}

scaleDownPDReplicas() {
  log "Scaling down pingdirectory replicas to ${1}"
  kubectl scale --replicas=${1} statefulset/pingdirectory -n "${PING_CLOUD_NAMESPACE}"
}

waitForNewPDReplicaIsReady() {
  # Get new pingdirectory pod name based on replica index
  local pd_replica_index=${1}
  local new_pod_name=$(kubectl get pods pingdirectory-${pd_replica_index} -n "${PING_CLOUD_NAMESPACE}" -o jsonpath='{.metadata.name}')

  # Wait for pod to be scheduled
  log "Waiting for ${new_pod_name} to be assigned to a node..."
  if ! kubectl wait --for=jsonpath='{.spec.nodeName}' pod/"${new_pod_name}" -n "${PING_CLOUD_NAMESPACE}" --timeout=120s; then
    log "ERROR: Pod ${new_pod_name} was not scheduled checking for events..."
    kubectl get events -n "${PING_CLOUD_NAMESPACE}" --field-selector involvedObject.name="${new_pod_name}"
    exit 1
  fi

  # Identify assigned node
  assigned_node=$(kubectl get pod "${new_pod_name}" -n "${PING_CLOUD_NAMESPACE}" -o jsonpath='{.spec.nodeName}')
  log "Pod ${new_pod_name} was scheduled on node ${assigned_node}"
}

oneTimeSetUp() {
  log "Capturing starting number of pingdirectory replicas"
  starting_pd_replicas=$(kubectl get statefulset pingdirectory -n "${PING_CLOUD_NAMESPACE}" -o jsonpath='{.spec.replicas}')
  
  if [[ -z "${starting_pd_replicas}" ]]; then
    fail "Could not determine starting replicas; aborting test."
    exit 1
  fi

  log "Starting pingdirectory replicas: ${starting_pd_replicas}"
}

testSystemScaling() {
  local new_replica_count=$((starting_pd_replicas + 1))
  # Replica index starts a 0, so the new replica index number will be the same as the startingreplica count before scaling up
  local new_pod_replica_index=$((starting_pd_replicas))

  # Increment replicas by 1
  scaleUpPDReplicas ${new_replica_count}

  waitForNewPDReplicaIsReady ${new_pod_replica_index}

  assertNotNull "New pingdirectory pod was not scheduled" "${assigned_node}"
  
  # Determine if we are testing cluster-autoscaler or karpenter
  if [[ "${CLUSTER_AUTOSCALER_ENABLED}" == "true" ]]; then
    log "Testing cluster-autoscaler scaling"

    # Check for the PD label
    local pd_label=$(kubectl get node "${assigned_node}" -o jsonpath='{.metadata.labels.pingidentity\.com/pd}')
    log "Node ${assigned_node} has pd label: ${pd_label}"

    assertEquals "Node ${assigned_node} is missing expected PD label" "true" "${pd_label}"
  else
    log "Testing karpenter scaling"

    # Check nodepool
    local nodepool_label=$(kubectl get node "${assigned_node}" -o jsonpath='{.metadata.labels.karpenter\.sh/nodepool}')
    log "Node ${assigned_node} is using Karpenter nodepool: ${nodepool_label}"
    
    assertEquals "Pod scheduled on wrong nodepool" "pd-only" "${nodepool_label}"
  fi
}

oneTimeTearDown() {
  log "Teardown: Restoring original pingdirectory replicas to ${starting_pd_replicas}"
  scaleDownPDReplicas "${starting_pd_replicas}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}