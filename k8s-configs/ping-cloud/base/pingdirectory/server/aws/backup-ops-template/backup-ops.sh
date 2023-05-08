#!/bin/bash

# Set as a function for this script if kubectl isn't installed.
# Assume kubectl is available for pod under /tmp/kubectl.
if ! command -v kubectl >/dev/null 2>&1; then
  # Check and see if kubectl is installed under /tmp.
  # If so, then source kubectl method which will be used by pod
  test -f /tmp/kubectl || (echo "kubectl is not installed: exiting" && exit 1)
  function kubectl() {
    /tmp/kubectl "${@}"
  }
fi

execution_type=${1-"manual-job"}

echo "Executed By: ${execution_type}"

# Set ping-cloud PING_CLOUD_NAMESPACE
# Note: The regular expression \bping-cloud\S* matches any string that starts with "ping-cloud" (\bping-cloud) and has zero or more non-space characters after it (\S*).
# e.g.
# A CDE with ping-cloud namespace will set the variable NAMESPACE as 'ping-cloud'
# A CDE with ping-cloud-username namespace will set the variable NAMESPACE as 'ping-cloud-username'
if [ -z "${PING_CLOUD_NAMESPACE}" ]; then
  export PING_CLOUD_NAMESPACE=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}{"\n"}' | grep -o -E "\bping-cloud\S*")
fi

# Get desired PingDirectory pod name
if [ -z "${BACKUP_RESTORE_POD}" ]; then
  export BACKUP_RESTORE_POD=$(kubectl get configmap pingdirectory-environment-variables -o jsonpath='{.data.BACKUP_RESTORE_POD}' -n "${PING_CLOUD_NAMESPACE}")
fi

# Get desired PingDirectory PVC size
# TODO- Ticket to dynamically get the PD size using kubemetrics/prometheus https://pingidentity.atlassian.net/browse/PDO-4958
if [ -z "${PINGDIRECTORY_PVC_SIZE}" ]; then
  export PINGDIRECTORY_PVC_SIZE=$(kubectl get pvc "out-dir-${BACKUP_RESTORE_POD}" -o jsonpath='{.spec.resources.requests.storage}' -n "${PING_CLOUD_NAMESPACE}")
fi

# Create ConfigMap and PersistentVolumeClaim first as the Job is dependent on these resources during the mounting stage of the pod.
# However, the configmap and pvc are independent and can be created in any order.
kubectl get configmap pingdirectory-backup-ops-template-files -o jsonpath='{.data.backup-cm\.yaml}' -n "${PING_CLOUD_NAMESPACE}" | kubectl apply -f - -n "${PING_CLOUD_NAMESPACE}"
kubectl get configmap pingdirectory-backup-ops-template-files -o jsonpath='{.data.backup-pvc\.yaml}' -n "${PING_CLOUD_NAMESPACE}" | envsubst | kubectl apply -f - -n "${PING_CLOUD_NAMESPACE}"
kubectl get configmap pingdirectory-backup-ops-template-files -o jsonpath='{.data.backup-job\.yaml}' -n "${PING_CLOUD_NAMESPACE}" | envsubst | kubectl apply -f - -n "${PING_CLOUD_NAMESPACE}"
