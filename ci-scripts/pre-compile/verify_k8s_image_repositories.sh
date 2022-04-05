#!/bin/bash

SCRIPT_HOME=$(
  cd $(dirname ${0})
  pwd
)
. ${SCRIPT_HOME}/../common.sh "${1}"

PING_CLOUD_BASE_DIR="${PROJECT_DIR}/k8s-configs"

########################################################################################################################
# Performs a 'grep' on each yaml file within the given path.
# Arguments
#   $1 -> base directory path.
#
# Returns
#   0 on success; non-zero on failure.
########################################################################################################################
verify_k8s_image_repositories() {

  local path="${1}"

  search_dev_image=$(find "${path}" -type f -name "*.yaml" -exec grep 'public.ecr.aws/r2h3l6e4/.' {} \; | grep "/dev/")
  if test -z "$search_dev_image"; then
    echo "$search_dev_image"
    return 0
  else
    echo "$search_dev_image"
    return 1
  fi

}

#verify k8s image repositories
verify_k8s_image_repositories "${PING_CLOUD_BASE_DIR}"
