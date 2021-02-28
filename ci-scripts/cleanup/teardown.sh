#!/bin/bash

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

# Do not ever delete the environment on the master branch. And only delete an environment,
# if the DELETE_ENV_AFTER_PIPELINE flag is true
if test "${CI_COMMIT_REF_SLUG}" = 'master' || test "${DELETE_ENV_AFTER_PIPELINE}" = 'false'; then
  log "Not deleting environment ${NAMESPACE}"
else
  # Configure kube config, unless skipped
  configure_kube

  log "Deleting environment ${NAMESPACE}"
  kubectl delete namespace "${NAMESPACE}"
fi
