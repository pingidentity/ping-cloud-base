#!/bin/bash -e

# WARNING: This script must only be used to seed the initial cluster state. It is destructive and will replace the
# contents of the remote branches corresponding to the different Customer Deployment Environments with new state.

# NOTE: This script must be run from the root of the cluster state repo clone directory. It acts on the following
# environment variables.
#
#   GENERATED_CODE_DIR -> The TARGET_DIR of generate-cluster-state.sh. Defaults to '/tmp/sandbox', if unset.
#   IS_PRIMARY -> A flag indicating whether or not this is the primary region. Defaults to false, if unset.
#   ENVIRONMENTS -> A space-separated list of environments. Defaults to 'dev test stage prod', if unset. If provided,
#       it must contain all or a subset of the environments currently created by the generate-cluster-state.sh script,
#       i.e. dev, test, stage, prod.
#   PUSH_RETRY_COUNT -> The number of times to try pushing to the cluster state repo with a 2s sleep between each
#       attempt to avoid IAM permission to repo sync issue.
#   PUSH_TO_SERVER -> A flag indicating whether or not to push the code to the remote server. Defaults to true.

# Global variables
K8S_CONFIGS_DIR='k8s-configs'
CLUSTER_STATE_DIR='cluster-state'
PROFILES_DIR='profiles'
BASE_DIR='base'

########################################################################################################################
# Organizes the Kubernetes configuration files to push into the cluster state repo for a specific Customer Deployment
# Environment (CDE).
#
# Arguments
#   ${1} -> The directory where cluster state code was generated, i.e. the TARGET_DIR to generate-cluster-state.sh.
#   ${2} -> The environment.
#   ${3} -> The output empty directory into which to organize the code to push for the environment and region.
#   ${4} -> Flag indicating whether or not the provided region is the primary region.
########################################################################################################################
organize_code_for_environment() {
  local generated_code_dir="${1}"
  local env="${2}"
  local out_dir="${3}"
  local is_primary="${4}"

  local dst_k8s_dir="${out_dir}/${K8S_CONFIGS_DIR}"
  local src_env_dir="${generated_code_dir}/${CLUSTER_STATE_DIR}/${K8S_CONFIGS_DIR}/${env}"
  local region="$(ls "${src_env_dir}" | grep -v "${BASE_DIR}")"

  "${is_primary}" && type='primary' || type='secondary'
  echo "Organizing code for environment '${env}' into '${out_dir}' for ${type} region '${region}'"

  if "${is_primary}"; then
    # For the primary region, we need to copy everything (i.e. both the k8s-configs and the profiles)
    # into the cluster state repo.

    # Copy everything under cluster state into the code directory for the environment.
    cp -pr "${generated_code_dir}/${CLUSTER_STATE_DIR}"/. "${out_dir}"

    # Remove everything under the k8s-configs because code is initially generated for every CDE under there.
    rm -rf "${dst_k8s_dir:?}"/*
  fi

  # Copy the environment-specific k8s-configs.
  cp -pr "${src_env_dir}"/. "${dst_k8s_dir}"
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
ALL_ENVIRONMENTS='dev test stage prod'
ENVIRONMENTS="${ENVIRONMENTS:-${ALL_ENVIRONMENTS}}"

GENERATED_CODE_DIR="${GENERATED_CODE_DIR:-/tmp/sandbox}"
IS_PRIMARY="${IS_PRIMARY:-false}"

PUSH_RETRY_COUNT="${PUSH_RETRY_COUNT:-30}"
PUSH_TO_SERVER="${PUSH_TO_SERVER:-true}"
PCB_COMMIT_SHA=$(cat "${GENERATED_CODE_DIR}"/pcb-commit-sha.txt)

for ENV in ${ENVIRONMENTS}; do
  echo "Processing ${ENV}"

  ENV_CODE_DIR=$(mktemp -d)
  ENV_SUFFIX="${ENV##*-}"
  test "${ENV_SUFFIX}" = 'master' && ENV_SUFFIX='prod'

  organize_code_for_environment "${GENERATED_CODE_DIR}" "${ENV_SUFFIX}" "${ENV_CODE_DIR}" "${IS_PRIMARY}"

  test "${ENV}" = 'prod' &&
      GIT_BRANCH=master ||
      GIT_BRANCH="${ENV}"

  git restore .

  # Check if the branch exists on remote. If so, switch to it and pull the latest code from it.
  if git ls-remote --quiet --heads | grep "${GIT_BRANCH}" &> /dev/null; then
    git checkout "${GIT_BRANCH}"
    git pull -X theirs

  # Otherwise, check if the branch exists locally. If so, get a clean checkout of it.
  elif git rev-parse --verify "${GIT_BRANCH}" &> /dev/null; then
    git checkout "${GIT_BRANCH}"

  # Otherwise, create it.
  else
    git checkout -b "${GIT_BRANCH}"
  fi

  if "${IS_PRIMARY}"; then
    # Clean-up
    echo "Cleaning up ${PWD}"
    rm -rf ./*
    mkdir -p "${K8S_CONFIGS_DIR}"

    # Copy the base files into the environment directory.
    src_dir="${ENV_CODE_DIR}"
    echo "Copying base files from ${src_dir} to ${PWD}"
    find "${src_dir}" -type f -maxdepth 1 | xargs -I {} cp {} ./

    # Copy the profiles directory.
    src_dir="${ENV_CODE_DIR}/${PROFILES_DIR}"
    echo "Copying ${src_dir} to ${PWD}"
    cp -pr "${src_dir}" ./

    # Copy bases files into the k8s-configs directory.
    src_dir="${GENERATED_CODE_DIR}/${CLUSTER_STATE_DIR}/${K8S_CONFIGS_DIR}"
    echo "Copying base files from ${src_dir} to ${K8S_CONFIGS_DIR}"
    find "${src_dir}" -type f -maxdepth 1 | xargs -I {} cp {} "${K8S_CONFIGS_DIR}"

    # Copy the k8s-configs/base directory, which is common code for all regions.
    src_dir="${ENV_CODE_DIR}/${K8S_CONFIGS_DIR}/${BASE_DIR}"
    echo "Copying ${src_dir} to ${K8S_CONFIGS_DIR}"
    cp -pr "${src_dir}" "${K8S_CONFIGS_DIR}/"
  fi

  region="$(ls "${ENV_CODE_DIR}/${K8S_CONFIGS_DIR}" | grep -v "${BASE_DIR}")"
  src_dir="${ENV_CODE_DIR}/${K8S_CONFIGS_DIR}/${region}"

  echo "Copying ${src_dir} to ${K8S_CONFIGS_DIR}"
  cp -pr "${src_dir}" "${K8S_CONFIGS_DIR}/"

  commit_msg="Initial commit of code for environment '${ENV}' in region '${region}' - ping-cloud-base@${PCB_COMMIT_SHA}"
  echo "${commit_msg}"

  git add .
  git commit --allow-empty -m "${commit_msg}"

  if "${PUSH_TO_SERVER}"; then
    push_with_retries "${PUSH_RETRY_COUNT}" "${GIT_BRANCH}"
  else
    echo "Not pushing changes to the server for branch '${GIT_BRANCH}'"
  fi

  echo
  echo ---
  echo
done