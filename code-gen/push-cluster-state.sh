#!/bin/bash -e

# WARNING: This script must only be used to seed the initial cluster state. It is destructive and will replace the
# contents of the remote branches corresponding to the different Customer Deployment Environments with new state.

# NOTE: This script must be run from the root of the cluster state repo clone directory. It acts on the following
# environment variables.
#
#   GENERATED_CODE_DIR -> The TARGET_DIR of generate-cluster-state.sh. Defaults to '/tmp/sandbox', if unset.
#   REGION_NAME -> The name of the region for which the generated code is applicable. This parameter is required.
#   ENVIRONMENTS -> A space-separated list of environments. Defaults to 'dev test stage prod', if unset. If provided,
#   it must contain all or a subset of the environments currently created by the generate-cluster-state.sh script, i.e.
#   dev, test, stage, prod.
#   PUSH_RETRY_COUNT -> The number of times to try pushing to the cluster state repo with a 2s sleep between each
#   attempt to avoid IAM permission to repo sync issue.

########################################################################################################################
# Organizes the Kubernetes configuration files to push into the cluster state repo for a specific Customer Deployment
# Environment (CDE). After this function completes, the code for the environment and region will be organized in the
# directory to which ENV_CODE_DIR points.
#
# Arguments
#   ${1} -> The directory where cluster state code was generated, i.e. the TARGET_DIR to generate-cluster-state.sh.
#   ${2} -> The environment.
#   ${3} -> The output empty directory into which to organize the code to push for the environment and region.
#   ${4} -> The name for a region, e.g. parent, child-0, child-1, etc.
#   ${5} -> Flag indicating whether or not the provided region is the parent.
########################################################################################################################
organize_code_for_environment() {
  local generated_code_dir="${1}"
  local env="${2}"
  local out_dir="${3}"
  local region_name="${4}"
  local is_parent="${5}"

  echo "Organizing code for environment ${env} in directory ${out_dir} for region ${region_name} (parent: ${is_parent})"
  if "${is_parent}"; then
    ENV_CODE_DIR="${out_dir}"
    cp -pr "${generated_code_dir}"/cluster-state/. "${ENV_CODE_DIR}"
  else
    ENV_CODE_DIR="${out_dir}/${region_name}"
  fi

  local k8s_dir="${ENV_CODE_DIR}"/k8s-configs
  rm -rf "${k8s_dir:?}"

  mkdir -p "${k8s_dir}"
  cp -pr "${generated_code_dir}"/cluster-state/k8s-configs/"${env}"/. "${k8s_dir}"
}

########################################################################################################################
# Attempt to push to the provided branch on the cluster state repo up to the specified number of retries.
#
# Arguments
#   ${1} -> Retry count.
#   ${2} -> The git branch to push to on origin.
########################################################################################################################
push_with_retries() {
  local retry_count=${1}
  local git_branch=${2}
  local attempt=1

  for attempt in $(seq 1 "${retry_count}"); do
    echo "Attempt #${attempt} pushing to server"
    git push --set-upstream origin "${git_branch}" && return 0
    sleep 2s
  done

  echo "Unable to push to server branch ${git_branch} after ${retry_count} attempts"
  return 1
}

### Script start ###
if test -z "${REGION_NAME}" || test -z "${IS_PARENT}"; then
  echo "REGION_NAME and IS_PARENT are required variables"
  exit 1
fi

ALL_ENVIRONMENTS='dev test stage prod'

ENVIRONMENTS="${ENVIRONMENTS:-${ALL_ENVIRONMENTS}}"
GENERATED_CODE_DIR="${GENERATED_CODE_DIR:-/tmp/sandbox}"

PUSH_RETRY_COUNT="${PUSH_RETRY_COUNT:-30}"
PCB_COMMIT_SHA=$(cat "${GENERATED_CODE_DIR}"/pcb-commit-sha.txt)

for ENV in ${ENVIRONMENTS}; do
  echo "Processing ${ENV}"

  OUT_DIR=$(mktemp -d)
  organize_code_for_environment "${GENERATED_CODE_DIR}" "${ENV}" "${OUT_DIR}" "${REGION_NAME}" "${IS_PARENT}"

  if test "${ENV}" != 'prod'; then
    GIT_BRANCH="${ENV}"
    # Check if the branch exists on remote. If so, switch to it and pull the latest code from it.
    if git ls-remote --quiet --heads | grep "${GIT_BRANCH}" &> /dev/null; then
      git restore .
      git checkout "${GIT_BRANCH}"
      git pull
    else
      # Check if the branch exists locally. If so, switch to master first and then delete it.
      if git rev-parse --verify "${GIT_BRANCH}" &> /dev/null; then
        git restore .
        git checkout master
        git branch -D "${GIT_BRANCH}"
      fi
      git checkout -b "${GIT_BRANCH}"
    fi
  else
    GIT_BRANCH=master
    git restore .
    git checkout "${GIT_BRANCH}"
    git pull
  fi

  if "${IS_PARENT}"; then
    rm -rf ./*
    cp -pr "${ENV_CODE_DIR}"/. .
  else
    rm -rf ./"${REGION_NAME}"
    cp -pr "${ENV_CODE_DIR}" .
  fi

  git add .
  git commit -m "Initial commit of code for ${REGION_NAME} - ping-cloud-base@${PCB_COMMIT_SHA}"
  push_with_retries "${PUSH_RETRY_COUNT}" "${GIT_BRANCH}"

  echo
  echo ---
  echo
done