#!/bin/bash

set -e

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

# Configure kubectl, unless skipped
configure_kube

PWD=$(pwd)
PCB_ROOT=${PWD/ping-cloud-base\/*/ping-cloud-base}
source "${PCB_ROOT}/pingcloud-scripts.sh"

K8S_UTILS_VERSION=1.0.1
pingcloud-scripts::source_script k8s_utils ${K8S_UTILS_VERSION}

# PingOne teardown
pip_install_shared_pingone_scripts
log "Deleting P1 resources created by deployment"
p1_deployment_cleanup
log "Deleting P1 Environment"
cicd_p1_env_setup_and_teardown Teardown

# Do not ever delete the environment on the master branch. And only delete an environment,
# if the DELETE_ENV_AFTER_PIPELINE flag is true
if test "${CI_COMMIT_REF_SLUG}" = 'master' || test "${DELETE_ENV_AFTER_PIPELINE}" = 'false'; then
  log "Not deleting environment ${PING_CLOUD_NAMESPACE}"
  log "Not deleting PingCentral database ${MYSQL_DATABASE} from host ${MYSQL_SERVICE_HOST}"
  exit 0
fi

utils::cleanup_k8s_resources

pod_name="mysql-client-${CI_COMMIT_REF_SLUG}"
MYSQL_USER=$(get_ssm_val "${MYSQL_USER_SSM}")
MYSQL_PASSWORD=$(get_ssm_val "${MYSQL_PASSWORD_SSM}")

log "Deleting PingCentral databases ${MYSQL_DATABASE} and p1_${MYSQL_DATABASE} from host ${MYSQL_SERVICE_HOST}"
kubectl run -n default -i "${pod_name}" --restart=Never --rm --image=arey/mysql-client -- \
      -h "${MYSQL_SERVICE_HOST}" -P ${MYSQL_SERVICE_PORT} \
      -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
      -e "drop database IF EXISTS ${MYSQL_DATABASE}; drop database IF EXISTS p1_${MYSQL_DATABASE}"

#cleanup the dns records before we release the ci-cd cluster that is currently in use
delete_dns_records "${TENANT_DOMAIN}"

# Sometimes, the cron job on the cluster - "cleanup-nondefault-namespaces" might clean up the lock before we can. 
# So check if it exists first.
if kubectl get ns cluster-in-use-lock > /dev/null 2>&1; then
  # Finally, delete the cluster-in-use-lock namespace. Do this last so that the cluster is clear for use by the next branch
  log "cluster-in-use-lock namespace synchronously deleting (will exit when done)"
  kubectl delete ns cluster-in-use-lock
fi