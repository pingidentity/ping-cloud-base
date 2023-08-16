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

# Set ping-cloud PING_CLOUD_NAMESPACE
# Note: The regular expression \bping-cloud\S* matches any string that starts with "ping-cloud" (\bping-cloud) and has zero or more non-space characters after it (\S*).
# e.g.
# A CDE with ping-cloud namespace will set the variable NAMESPACE as 'ping-cloud'
# A CDE with ping-cloud-username namespace will set the variable NAMESPACE as 'ping-cloud-username'
if [ -z "${PING_CLOUD_NAMESPACE}" ]; then
  export PING_CLOUD_NAMESPACE=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}{"\n"}' | grep -o -E "\bping-cloud\S*")
fi

# Get desired backends to restore in pingdirectory pod
if [ -z "${BACKENDS_TO_RESTORE}" ]; then
  export BACKENDS_TO_RESTORE=$(kubectl get cm "pingdirectory-environment-variables" -o jsonpath='{.data.BACKENDS_TO_RESTORE}' -n "${PING_CLOUD_NAMESPACE}")
fi

# Get desired PingDirectory pod name
if [ -z "${BACKUP_RESTORE_POD}" ]; then
  export BACKUP_RESTORE_POD=$(kubectl get configmap pingdirectory-environment-variables -o jsonpath='{.data.BACKUP_RESTORE_POD}' -n "${PING_CLOUD_NAMESPACE}")
fi

# Get desired PingDirectory PVC size
if [ -z "${PINGDIRECTORY_PVC_SIZE}" ]; then
  export PINGDIRECTORY_PVC_SIZE=$(kubectl get pvc "out-dir-${BACKUP_RESTORE_POD}" -o jsonpath='{.spec.resources.requests.storage}' -n "${PING_CLOUD_NAMESPACE}")
fi

# Get desired backup file name to restore in pingdirectory pod
if [ -z "${BACKUP_FILE_NAME}" ]; then
  export BACKUP_FILE_NAME=$(kubectl get cm "pingdirectory-environment-variables" -o jsonpath='{.data.BACKUP_FILE_NAME}' -n "${PING_CLOUD_NAMESPACE}")
fi

# Create ConfigMap and PersistentVolumeClaim first as the Job is dependent on these resources during the mounting stage of the pod.
# However, the configmap and pvc are independent and can be created in any order.
kubectl get configmap pingdirectory-restore-ops-template-files -o jsonpath='{.data.restore-cm\.yaml}'  -n "${PING_CLOUD_NAMESPACE}" | kubectl apply -f - -n "${PING_CLOUD_NAMESPACE}"
kubectl get configmap pingdirectory-restore-ops-template-files -o jsonpath='{.data.restore-pvc\.yaml}' -n "${PING_CLOUD_NAMESPACE}" | envsubst | kubectl apply -f - -n "${PING_CLOUD_NAMESPACE}"
kubectl get configmap pingdirectory-restore-ops-template-files -o jsonpath='{.data.restore-job\.yaml}' -n "${PING_CLOUD_NAMESPACE}" | envsubst | kubectl apply -f - -n "${PING_CLOUD_NAMESPACE}"