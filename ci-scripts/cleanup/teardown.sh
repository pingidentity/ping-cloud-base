#!/bin/bash

set -e

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

# Configure aws and kubectl, unless skipped
configure_aws
configure_kube

# If PingOne teardown just delete the PingOne environment and exit
if [[ -n ${PINGONE} ]]; then
  set_pingone_api_env_vars
  log "Deleting P1 Environment"
  pip3 install -r ${PROJECT_DIR}/ci-scripts/deploy/ping-one/requirements.txt
  python3 ${PROJECT_DIR}/ci-scripts/deploy/ping-one/p1_env_setup_and_teardown.py Teardown
  exit 0
fi

# Do not ever delete the environment on the master branch. And only delete an environment,
# if the DELETE_ENV_AFTER_PIPELINE flag is true
if test "${CI_COMMIT_REF_SLUG}" = 'master' || test "${DELETE_ENV_AFTER_PIPELINE}" = 'false'; then
  log "Not deleting environment ${PING_CLOUD_NAMESPACE}"
  log "Not deleting PingCentral database ${MYSQL_DATABASE} from host ${MYSQL_SERVICE_HOST}"
  exit 0
fi

# Get all Custom Resource Definitions so we can gracefully delete the objects before terminating the namespace
# remove clusterissuers.cert-manager.io from the list because it isn't namespaced
all_crds=$(kubectl get crds --no-headers -o custom-columns=":metadata.name" | grep -v "clusterissuers.cert-manager.io" | tr "\n" "," | sed -e 's/,$//')

all_namespaces=$(kubectl get ns -o name)
deleting_ns=()

for ns in $all_namespaces; do
  if [[ $ns == *"kube-"* || $ns == "namespace/default" || $ns == *"cluster-in-use-lock"* ]]; then
    log "Skipping namespace ${ns}"
    continue
  fi
  log "Deleting namespaced CRDs"
  kubectl delete "${all_crds}" --all -n "${ns#"namespace/"}"
  log "Deleting namespace asynchronously: ${ns}"
  kubectl delete "${ns}" --wait=false
  deleting_ns+=($ns)
done

pod_name="mysql-client-${CI_COMMIT_REF_SLUG}"
MYSQL_USER=$(get_ssm_val "${MYSQL_USER_SSM}")
MYSQL_PASSWORD=$(get_ssm_val "${MYSQL_PASSWORD_SSM}")

log "Deleting PingCentral databases ${MYSQL_DATABASE} and p1_${MYSQL_DATABASE} from host ${MYSQL_SERVICE_HOST}"
kubectl run -n default -i "${pod_name}" --restart=Never --rm --image=arey/mysql-client -- \
      -h "${MYSQL_SERVICE_HOST}" -P ${MYSQL_SERVICE_PORT} \
      -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
      -e "drop database IF EXISTS ${MYSQL_DATABASE}; drop database IF EXISTS p1_${MYSQL_DATABASE}"

wait_time=15

for ns in "${deleting_ns[@]}"; do
  while kubectl get ns -o name | grep $ns > /dev/null; do
    log "Waiting for namespace ${ns} to terminate"
    log "Sleeping for ${wait_time} seconds and trying again"
    sleep ${wait_time}
  done
done

# Sometimes, the cron job on the cluster - "cleanup-nondefault-namespaces" might clean up the lock before we can. 
# So check if it exists first.
if kubectl get ns cluster-in-use-lock > /dev/null 2>&1; then
  # Finally, delete the cluster-in-use-lock namespace. Do this last so that the cluster is clear for use by the next branch
  log "cluster-in-use-lock namespace synchronously deleting (will exit when done)"
  kubectl delete ns cluster-in-use-lock
fi