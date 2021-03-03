#!/bin/bash

# If VERBOSE is true, then output line-by-line execution
"${VERBOSE:-false}" && set -x

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
# Delete all files and directories under the provided directory. All hidden files and directories directly under the
# provided directory will be left intact.
#
# Arguments
#   ${1} -> The directory to clean up.
########################################################################################################################
dir_deep_clean() {
  dir="$1"
  if test -d "${dir}"; then
    echo "Contents of directory ${dir} before deletion:"
    find "${dir}" -mindepth 1 -maxdepth 1
    find "${dir}" -mindepth 1 -maxdepth 1 -not -path "${dir}/.*" -exec rm -rf {} +
    echo "Contents of directory ${dir} after deletion:"
    find "${dir}" -mindepth 1 -maxdepth 1
  fi
}

########################################################################################################################
# Organizes the Kubernetes configuration files to push into the cluster state repo for a specific Customer Deployment
# Environment (CDE).
#
# Arguments
#   ${1} -> The directory where cluster state code was generated, i.e. the TARGET_DIR to generate-cluster-state.sh.
#   ${2} -> The name of the directory under which the sources for the environment may be found in generated code.
#   ${3} -> The environment type, i.e. dev, test, stage or prod.
#   ${4} -> The output empty directory into which to organize the code to push for the environment and region.
#   ${5} -> Flag indicating whether or not the provided region is the primary region.
########################################################################################################################
organize_code_for_environment() {
  generated_code_dir="${1}"
  src_rel_dir_for_env="${2}"
  env="${3}"
  out_dir="${4}"
  is_primary="${5}"

  dst_k8s_dir="${out_dir}/${K8S_CONFIGS_DIR}"
  src_env_dir="${generated_code_dir}/${CLUSTER_STATE_DIR}/${K8S_CONFIGS_DIR}/${src_rel_dir_for_env}"
  # shellcheck disable=SC2010
  region="$(ls "${src_env_dir}" | grep -v "${BASE_DIR}")"

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
  retry_count=${1}
  git_branch=${2}
  attempt=1

  for attempt in $(seq 1 "${retry_count}"); do
    echo "Attempt #${attempt} pushing to server"
    git push --set-upstream origin "${git_branch}" && return 0
    sleep 2s
  done

  echo "Unable to push to server branch ${git_branch} after ${retry_count} attempts"
  return 1
}

########################################################################################################################
# Switch back to the previous branch and delete the staging branch.
########################################################################################################################
finalize() {
  git checkout --quiet "${CURRENT_BRANCH}"
  git branch -D "${STAGING_BRANCH}"
}

### Script start ###

# Quiet mode where pretty console-formatting is omitted.
QUIET="${QUIET:-false}"

ALL_ENVIRONMENTS='dev test stage prod'
ENVIRONMENTS="${ENVIRONMENTS:-${ALL_ENVIRONMENTS}}"

GENERATED_CODE_DIR="${GENERATED_CODE_DIR:-/tmp/sandbox}"
IS_PRIMARY="${IS_PRIMARY:-false}"

PUSH_RETRY_COUNT="${PUSH_RETRY_COUNT:-30}"
PUSH_TO_SERVER="${PUSH_TO_SERVER:-true}"
PCB_COMMIT_SHA=$(cat "${GENERATED_CODE_DIR}"/pcb-commit-sha.txt)

# This is a destructive script by design. Add a warning to the user if local changes are being destroyed though.
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if test -n "$(git status -s)"; then
  echo "WARN: The following local changes in current branch '${CURRENT_BRANCH}' will be destroyed:"
  git status
fi

# Set the git merge strategy to avoid noisy hints in the output.
git config pull.rebase false

# Get rid of staged/un-staged modifications and untracked files/directories (including ignored ones) on current branch.
# Otherwise, you cannot switch to another branch.
git reset --hard HEAD
git clean -fdx

# Create a staging branch from which to create new branches.
STAGING_BRANCH="staging-branch-$(date +%s)"
echo "Creating staging branch '${STAGING_BRANCH}'"
git checkout -b "${STAGING_BRANCH}"

# Get a list of the remote branches from the server.
git pull &> /dev/null
REMOTE_BRANCHES="$(git ls-remote --quiet --heads 2> /dev/null)"
LS_REMOTE_EXIT_CODE=$?

if test ${LS_REMOTE_EXIT_CODE} -ne 0; then
  echo "WARN: Unable to retrieve remote branches from the server. Exit code: ${LS_REMOTE_EXIT_CODE}"
fi

# The ENVIRONMENTS variable can either be the CDE names (e.g. dev, test, stage, prod) or the branch names (e.g.
# v1.8.0-dev, v1.8.0-test, v1.8.0-stage, v1.8.0-master). It will be the CDE names on initial seeding of the cluster
# state repo. On upgrade of the cluster state repo it will be the branch names. We must handle both cases. Note that
# the 'prod' environment will have a branch name suffix of 'master'.
for ENV_OR_BRANCH in ${ENVIRONMENTS}; do
  test "${ENV_OR_BRANCH}" = 'prod' &&
      GIT_BRANCH='master' ||
      GIT_BRANCH="${ENV_OR_BRANCH}"
  DEFAULT_CDE_BRANCH="${GIT_BRANCH##*-}"

  ENV_OR_BRANCH_SUFFIX="${ENV_OR_BRANCH##*-}"
  test "${ENV_OR_BRANCH_SUFFIX}" = 'master' &&
      ENV='prod' ||
      ENV="${ENV_OR_BRANCH_SUFFIX}"

  echo "Processing branch '${GIT_BRANCH}' for CDE '${ENV}' and default CDE branch '${DEFAULT_CDE_BRANCH}'"

  ENV_CODE_DIR=$(mktemp -d)
  organize_code_for_environment "${GENERATED_CODE_DIR}" "${ENV_OR_BRANCH}" "${ENV}" "${ENV_CODE_DIR}" "${IS_PRIMARY}"

  # NOTE: this shouldn't be required here since we commit all changes before moving to the next branch. But it doesn't
  # hurt to have it as an extra pre-caution.

  # Get rid of staged/un-staged modifications and untracked files/directories (including ignored ones) on current
  # branch. Otherwise, you cannot switch to another branch.
  git reset --hard HEAD
  git clean -fdx

  # Check if the branch exists locally. If so, switch to it.
  if git rev-parse --verify "${GIT_BRANCH}" &> /dev/null; then
    echo "Branch ${GIT_BRANCH} exists locally. Switching to it."
    git checkout "${GIT_BRANCH}"

  # Otherwise, create it.
  else
    # Attempt to create the branch from its default CDE branch name.
    echo "Branch ${GIT_BRANCH} does not exist locally. Creating it."

    if git rev-parse --verify "${DEFAULT_CDE_BRANCH}" &> /dev/null; then
      echo "Switching to branch ${DEFAULT_CDE_BRANCH} before creating ${GIT_BRANCH}"
      git checkout --quiet "${DEFAULT_CDE_BRANCH}"
    else
      echo "Default CDE branch ${DEFAULT_CDE_BRANCH} does not exist for branch ${GIT_BRANCH}"
      echo "Creating it from branch: ${STAGING_BRANCH}"
      git checkout --quiet "${STAGING_BRANCH}"
    fi

    git checkout -b "${GIT_BRANCH}"
  fi

  # Check if the branch exists on remote. If so, pull the latest code from remote.
  if echo "${REMOTE_BRANCHES}" | grep -q "${GIT_BRANCH}" 2> /dev/null; then
    echo "Branch ${GIT_BRANCH} exists on server. Checking out latest code from server."
    git pull --no-edit origin "${GIT_BRANCH}" -X theirs
  elif test "${REMOTE_BRANCHES}"; then
    echo "Branch ${GIT_BRANCH} does not exist on server."
  fi

  if "${IS_PRIMARY}"; then
    # Clean-up
    echo "Cleaning up ${PWD}"
    dir_deep_clean "${PWD}"
    mkdir -p "${K8S_CONFIGS_DIR}"

    # Copy the base files into the environment directory.
    src_dir="${ENV_CODE_DIR}"
    echo "Copying base files from ${src_dir} to ${PWD}"
    find "${src_dir}" -type f -maxdepth 1 -exec cp {} ./ \;

    # Copy the profiles directory.
    src_dir="${ENV_CODE_DIR}/${PROFILES_DIR}"
    echo "Copying ${src_dir} to ${PWD}"
    cp -pr "${src_dir}" ./

    # Copy bases files into the k8s-configs directory.
    src_dir="${GENERATED_CODE_DIR}/${CLUSTER_STATE_DIR}/${K8S_CONFIGS_DIR}"
    echo "Copying base files from ${src_dir} to ${K8S_CONFIGS_DIR}"
    find "${src_dir}" -type f -maxdepth 1 -exec cp {} "${K8S_CONFIGS_DIR}" \;

    # Copy the k8s-configs/base directory, which is common code for all regions.
    src_dir="${ENV_CODE_DIR}/${K8S_CONFIGS_DIR}/${BASE_DIR}"
    echo "Copying ${src_dir} to ${K8S_CONFIGS_DIR}"
    cp -pr "${src_dir}" "${K8S_CONFIGS_DIR}/"
  fi

  # shellcheck disable=SC2010
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

  if ! "${QUIET}"; then
    echo
    echo ---
    echo
  fi
done

# Run any required finalization
finalize
