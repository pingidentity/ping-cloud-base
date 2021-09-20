#!/bin/bash

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

# Configure aws and kubectl, unless skipped
configure_aws
configure_kube

# Do not ever delete the environment on the master branch. And only delete an environment,
# if the DELETE_ENV_AFTER_PIPELINE flag is true
if test "${CI_COMMIT_REF_SLUG}" = 'master' || test "${DELETE_ENV_AFTER_PIPELINE}" = 'false'; then
  log "Not deleting environment ${NAMESPACE}"
  log "Not deleting PingCentral database ${MYSQL_DATABASE} from host ${MYSQL_SERVICE_HOST}"
else
  log "Deleting environment ${NAMESPACE}"
  kubectl delete namespace "${NAMESPACE}"

  log "Deleting PingCentral database ${MYSQL_DATABASE} from host ${MYSQL_SERVICE_HOST}"

  pod_name="mysql-client-${CI_COMMIT_REF_SLUG}"
  kubectl delete pod "${pod_name}"

  MYSQL_USER=$(get_ssm_val "${MYSQL_USER_SSM}")
  MYSQL_PASSWORD=$(get_ssm_val "${MYSQL_PASSWORD_SSM}")

  kubectl run -n default -i "${pod_name}" --restart=Never --rm --image=arey/mysql-client -- \
       -h "${MYSQL_SERVICE_HOST}" -P ${MYSQL_SERVICE_PORT} \
       -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
       -e "drop database ${MYSQL_DATABASE}"
fi

# Do not consider failure to cleanup a pipeline failure
exit 0