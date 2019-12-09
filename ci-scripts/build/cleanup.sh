#!/bin/bash

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

# Do not ever delete the environment on the master branch. And only delete an environment,
# if the DELETE_ENV_AFTER_PIPELINE flag is true
if test "${NAMESPACE}" = 'ping-cloud-master' || test "${DELETE_ENV_AFTER_PIPELINE}" = 'false'; then
  echo "Not deleting environment ${NAMESPACE}"
else
  # Configure kube config
  if test "${1}" != 'debug'; then
    echo "Configuring kube config"
    configure_kube
  fi

  echo "Deleting environment ${NAMESPACE}"
  kubectl delete namespace "${NAMESPACE}"
fi