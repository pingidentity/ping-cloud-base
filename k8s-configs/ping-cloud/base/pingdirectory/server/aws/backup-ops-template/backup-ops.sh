#!/bin/bash

execution_type="${1}"

if [ "${execution_type}" != "p1as-automation" ]; then
  echo "You are trying to execute backup-ops.sh script directly as it now being done through 'kubectl create Job' using P1AS automation."
  echo "See v1.19.2 upgrade guide for more details."
  exit 0
fi

# Set ping-cloud NAMESPACE
# Note: The regular expression \bping-cloud\S* matches any string that starts with "ping-cloud" (\bping-cloud) and has zero or more non-space characters after it (\S*).
# e.g.
# A CDE with ping-cloud namespace will set the variable NAMESPACE as 'ping-cloud'
# A CDE with ping-cloud-username namespace will set the variable NAMESPACE as 'ping-cloud-username'
if [ -z "${NAMESPACE}" ]; then
  export NAMESPACE=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}{"\n"}' | grep -o -E "\bping-cloud\S*")
fi

# Get desired PingDirectory pod name
if [ -z "${BACKUP_RESTORE_POD}" ]; then
  export BACKUP_RESTORE_POD=$(kubectl get configmap pingdirectory-environment-variables -o jsonpath='{.data.BACKUP_RESTORE_POD}' -n "${NAMESPACE}")
fi

# Get desired PingDirectory PVC size
# TODO- Ticket to dynamically get the PD size using kubemetrics/prometheus https://pingidentity.atlassian.net/browse/PDO-4958
if [ -z "${PINGDIRECTORY_PVC_SIZE}" ]; then
  export PINGDIRECTORY_PVC_SIZE=$(kubectl get pvc "out-dir-${BACKUP_RESTORE_POD}" -o jsonpath='{.spec.resources.requests.storage}' -n "${NAMESPACE}")
fi

# Create ConfigMap and PersistentVolumeClaim first as the Job is dependent on these resources during the mounting stage of the pod.
# However, the configmap and pvc are independent and can be created in any order.
kubectl get configmap pingdirectory-backup-ops-template-files -o jsonpath='{.data.backup-cm\.yaml}' -n "${NAMESPACE}" | kubectl apply -f - -n "${NAMESPACE}"
kubectl get configmap pingdirectory-backup-ops-template-files -o jsonpath='{.data.backup-pvc\.yaml}' -n "${NAMESPACE}" | envsubst | kubectl apply -f - -n "${NAMESPACE}"
kubectl get configmap pingdirectory-backup-ops-template-files -o jsonpath='{.data.backup-job\.yaml}' -n "${NAMESPACE}" | envsubst | kubectl apply -f - -n "${NAMESPACE}"
