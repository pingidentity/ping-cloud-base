#!/bin/bash

execution_type=${1-"manual-job"}

echo "Executed By: ${execution_type}"

if test "${execution_type}" == "manual-job"; then
  # Set ping-cloud PING_CLOUD_NAMESPACE
  # Note: The regular expression \bping-cloud\S* matches any string that starts with "ping-cloud" (\bping-cloud) and has zero or more non-space characters after it (\S*).
  # e.g.
  # A CDE with ping-cloud namespace will set the variable NAMESPACE as 'ping-cloud'
  # A CDE with ping-cloud-username namespace will set the variable NAMESPACE as 'ping-cloud-username'
  export PING_CLOUD_NAMESPACE=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}{"\n"}' | grep -o -E "\bping-cloud\S*")

  # Get desired PingDirectory pod name
  BACKUP_RESTORE_POD=$(kubectl get configmap pingdirectory-environment-variables -o jsonpath='{.data.BACKUP_RESTORE_POD}' -n "${PING_CLOUD_NAMESPACE}")
  K8S_STATEFUL_SET_NAME=$(kubectl get configmap pingdirectory-environment-variables -o jsonpath='{.data.K8S_STATEFUL_SET_NAME}' -n "${PING_CLOUD_NAMESPACE}")
  test -z "${BACKUP_RESTORE_POD}" && export PINGDIRECTORY_POD_NAME="${K8S_STATEFUL_SET_NAME}-0" || export PINGDIRECTORY_POD_NAME="${BACKUP_RESTORE_POD}"

  # Get desired PingDirectory PVC size
  export PINGDIRECTORY_PVC_SIZE=$(kubectl get pvc "out-dir-${PINGDIRECTORY_POD_NAME}" -o jsonpath='{.spec.resources.requests.storage}' -n "${PING_CLOUD_NAMESPACE}")

  parent_directory="$(dirname "$(realpath "$0")")"
  cat "${parent_directory}/backup-pvc.yaml" | envsubst | kubectl apply -f -
  cat "${parent_directory}/backup-cm.yaml"  | kubectl apply -f -
  cat "${parent_directory}/backup-job.yaml" | envsubst | kubectl apply -f -

else

  # Create kubectl alias to run kubectl command without absolute path of /tmp
  SERVER_PROFILE_BRANCH=master

  test -z "${BACKUP_RESTORE_POD}" && export PINGDIRECTORY_POD_NAME="${K8S_STATEFUL_SET_NAME}-0" || export PINGDIRECTORY_POD_NAME="${BACKUP_RESTORE_POD}"

  # Get desired PingDirectory PVC size
  export PINGDIRECTORY_PVC_SIZE=$(/tmp/kubectl get pvc "out-dir-${PINGDIRECTORY_POD_NAME}" -o jsonpath='{.spec.resources.requests.storage}' -n "${PING_CLOUD_NAMESPACE}")

  # TODO figure out a way to support dev environments by pulling remote resources from dev branch
  github_url="https://raw.githubusercontent.com/calvincarter-ping/ping-cloud-base/${SERVER_PROFILE_BRANCH}/backups-ops"
  curl "${github_url}/backup-pvc.yaml" | envsubst | /tmp/kubectl apply -f -
  curl "${github_url}/backup-ops/backup-cm.yaml"  | /tmp/kubectl apply -f -
  curl "${github_url}/backup-job.yaml" | envsubst | /tmp/kubectl apply -f -

fi