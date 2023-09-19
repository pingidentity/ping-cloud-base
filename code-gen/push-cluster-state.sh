#!/bin/bash

# If VERBOSE is true, then output line-by-line execution
"${VERBOSE:-false}" && set -x

# PREREQUISITES: Should be compatible with Debian.
#                This script is used by platform automation on Ubuntu (Debian) to push generated K8s manifest.
#
# WARNING: This script must only be used to seed the initial cluster state. It is destructive and will replace the
# contents of the remote branches corresponding to the different Customer Deployment Environments with new state.

# NOTE: This script must be run from the root of the cluster state repo clone directory. It acts on the following
# environment variables.
#
#   GENERATED_CODE_DIR -> The TARGET_DIR of generate-cluster-state.sh. Defaults to '/tmp/sandbox', if unset.
#   IS_PRIMARY -> A flag indicating whether or not this is the primary region. Defaults to false, if unset.
#   IS_PROFILE_REPO -> A flag indicating whether or not this push is targeted for the server profile repo. Defaults to
#       false, if unset.
#   INCLUDE_PROFILES_IN_CSR -> A flag indicating whether or not to include profile code into the CSR. Defaults to
#       true, if unset. This flag will be removed (or its default set to true) when Versent provisions a new profile
#       repo exclusively for server profiles.
#   SUPPORTED_ENVIRONMENT_TYPES -> A space-separated list of environments. Defaults to 'dev test stage prod customer-hub',
#       if unset. If provided, it must contain all or a subset of the environments currently created by the
#       generate-cluster-state.sh script, i.e. dev, test, stage, prod, customer-hub.
#   PUSH_RETRY_COUNT -> The number of times to try pushing to the cluster state repo with a 2s sleep between each
#       attempt to avoid IAM permission to repo sync issue.
#   PUSH_TO_SERVER -> A flag indicating whether or not to push the code to the remote server. Defaults to true.
#   DISABLE_GIT -> Don't interact with git, only change the file structure locally - best used for testing
#       git-ops-command.sh rendering of files as if in a CSR
#   APPS_TO_PUSH -> An optional space-separated list of apps to push. Defaults to everything, if unset
#       If provided, it must match the app directories that are created at the root of the cluster state repo,
#       i.e. 'k8s-configs p1as-beluga-tools'

# Global variables
CLUSTER_STATE_REPO_DIR='cluster-state'
K8S_CONFIGS_DIR='k8s-configs'
BASE_DIR='base'
ALL_APPS='all'

PROFILE_REPO_DIR='profile-repo'
PROFILES_DIR='profiles'

CUSTOMER_HUB='customer-hub'

DISABLE_GIT=${DISABLE_GIT:-false}

########################################################################################################################
# Delete all files and directories under the provided directory. All hidden files and directories directly under the
# provided directory will be left intact. Any glob specified through the RETAIN_GLOB environment variable will be
# ignored.
#
# Arguments
#   ${1} -> The directory to clean up.
########################################################################################################################
dir_deep_clean() {
  dir="$1"
  if test -d "${dir}"; then
    echo "Contents of directory ${dir} before deletion:"
    find "${dir}" -mindepth 1 -maxdepth 1
    # Allow a glob to be retained with an environment variable. For example,
    # users may want project files such as *.iml and *.vscode to be retained.
    if test "${RETAIN_GLOB}"; then
      find "${dir}" -mindepth 1 -maxdepth 1 -not -path "${dir}/.*" -not -path "${dir}/${RETAIN_GLOB}" -exec rm -rf {} +
    else
      find "${dir}" -mindepth 1 -maxdepth 1 -not -path "${dir}/.*" -exec rm -rf {} +
    fi
    echo "Contents of directory ${dir} after deletion:"
    find "${dir}" -mindepth 1 -maxdepth 1
  fi
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
# Returns a flag indicating whether this is for all apps or not
# Returns 0 if true, 1 if false
########################################################################################################################
is_all_apps() {
  test "${APPS_TO_PUSH}" = "${ALL_APPS}"
}

########################################################################################################################
# We need some way to identify that we are indeed within a cluster-state-repo or profile-repo before making irreversible
# changes. Therefore, check that either a 'profiles', 'values-files', or 'k8s-configs' (for monorepo backwards
# compatibility) directory exists, or that the directory is empty (besides hidden/dotfiles) in the case of a brand-new
# CSR/PR empty cloned repo
########################################################################################################################
dir_sanity_check() {
  echo "Checking if in a CSR or PR..."
  if [[ -d "profiles" || \
        -d "values-files" || \
        -d "k8s-configs" || \
        $(find . -mindepth 1 -not -path "./.*" | wc -l | tr -d '[:space:]') == 0 ]]; then
    return 0
  else
    return 1
  fi
}

########################################################################################################################
# Switch back to the previous branch and delete the staging branch.
########################################################################################################################
finalize() {
  if test "${CURRENT_BRANCH}"; then
    git checkout --quiet "${CURRENT_BRANCH}"
  fi
}

### Script start ###

if [[ "${IS_BELUGA_ENV}" == "true" ]]; then
  if ! dir_sanity_check; then
    echo "Directory sanity check failed, please check that you are running push-cluster-state.sh from a CSR or PR!!"
    exit 1
  fi
fi

# If profile repo and secondary region, early-out. The profiles will be exactly identical for all regions and should
# already have been seeded when this script was run on primary region.
IS_PRIMARY="${IS_PRIMARY:-false}"
IS_PROFILE_REPO="${IS_PROFILE_REPO:-false}"

if "${IS_PROFILE_REPO}" && ! "${IS_PRIMARY}"; then
  echo "Nothing to push to the profile repo for secondary regions"
  exit 0
fi

APPS_TO_PUSH=${APPS_TO_PUSH:-${ALL_APPS}}

# Quiet mode where pretty console-formatting is omitted.
QUIET="${QUIET:-false}"

ALL_ENVIRONMENTS='dev test stage prod customer-hub'
SUPPORTED_ENVIRONMENT_TYPES="${SUPPORTED_ENVIRONMENT_TYPES:-${ALL_ENVIRONMENTS}}"

GENERATED_CODE_DIR="${GENERATED_CODE_DIR:-/tmp/sandbox}"

INCLUDE_PROFILES_IN_CSR="${INCLUDE_PROFILES_IN_CSR:-false}"

PUSH_RETRY_COUNT="${PUSH_RETRY_COUNT:-30}"
PUSH_TO_SERVER="${PUSH_TO_SERVER:-true}"
PCB_COMMIT_SHA=$(cat "${GENERATED_CODE_DIR}"/pcb-commit-sha.txt)

# Set the git merge strategy to avoid noisy hints in the output.
if ! ${DISABLE_GIT}; then
  git config pull.rebase false
fi

# This is a destructive script by design. Add a warning to the user if local changes are being destroyed though.
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"
if test "${CURRENT_BRANCH}" && test -n "$(git status -s)" && ! ${DISABLE_GIT}; then
  echo "WARN: The following local changes in current branch '${CURRENT_BRANCH}' will be destroyed:"
  git status

  # Get rid of staged/un-staged modifications and untracked files/directories
  # on current branch. Otherwise, you cannot switch to another branch.
  git reset --hard HEAD
  git clean -fd
fi

REMOTE_BRANCHES=""

# Get a list of the remote branches from the server.
if ! ${DISABLE_GIT}; then
  git pull &> /dev/null
  REMOTE_BRANCHES="$(git ls-remote --quiet --heads 2> /dev/null)"
  LS_REMOTE_EXIT_CODE=$?

  if test ${LS_REMOTE_EXIT_CODE} -ne 0; then
    echo "WARN: Unable to retrieve remote branches from the server. Exit code: ${LS_REMOTE_EXIT_CODE}"
  fi
fi

# The SUPPORTED_ENVIRONMENT_TYPES variable can either be the CDE names or CHUB name (e.g. dev, test, stage, prod or customer-hub) or
# the branch names (e.g. v1.8.0-dev, v1.8.0-test, v1.8.0-stage, v1.8.0-master or v1.8.0-customer-hub). It will be the
# CDE names or CHUB name on initial seeding of the cluster state repo. On upgrade of the cluster state repo it will be
# the branch names. We must handle both cases. Note that the 'prod' environment will have a branch name suffix
# of 'master'.
for ENV_OR_BRANCH in ${SUPPORTED_ENVIRONMENT_TYPES}; do
  if echo "${ENV_OR_BRANCH}" | grep -q "${CUSTOMER_HUB}"; then
    GIT_BRANCH="${ENV_OR_BRANCH}"
    DEFAULT_CDE_BRANCH="${CUSTOMER_HUB}"

    ENV_OR_BRANCH_SUFFIX="${CUSTOMER_HUB}"
    ENV="${CUSTOMER_HUB}"
  else
    test "${ENV_OR_BRANCH}" = 'prod' &&
        GIT_BRANCH='master' ||
        GIT_BRANCH="${ENV_OR_BRANCH}"
    DEFAULT_CDE_BRANCH="${GIT_BRANCH##*-}"

    ENV_OR_BRANCH_SUFFIX="${ENV_OR_BRANCH##*-}"
    test "${ENV_OR_BRANCH_SUFFIX}" = 'master' &&
        ENV='prod' ||
        ENV="${ENV_OR_BRANCH_SUFFIX}"
  fi

  echo "Processing branch '${GIT_BRANCH}' for environment '${ENV}' and default branch '${DEFAULT_CDE_BRANCH}'"

  if is_all_apps; then
    # Get all app paths
    if "${IS_PROFILE_REPO}"; then
      APP_PATHS=$(find "${GENERATED_CODE_DIR}/${PROFILE_REPO_DIR}/${PROFILES_DIR}/${ENV_OR_BRANCH}" -mindepth 1 -maxdepth 1 -type d)
    else
      APP_PATHS=$(find "${GENERATED_CODE_DIR}/${CLUSTER_STATE_REPO_DIR}/${ENV_OR_BRANCH}" -mindepth 1 -maxdepth 1 -type d)
    fi
  else
    # Get only APPS_TO_PUSH paths
    for app in ${APPS_TO_PUSH}; do
      if "${IS_PROFILE_REPO}"; then
        APP_PATHS="${APP_PATHS}${GENERATED_CODE_DIR}/${PROFILE_REPO_DIR}/${PROFILES_DIR}/${ENV_OR_BRANCH}/${app} "
      else
        APP_PATHS="${APP_PATHS}${GENERATED_CODE_DIR}/${CLUSTER_STATE_REPO_DIR}/${ENV_OR_BRANCH}/${app} "
      fi
    done
  fi

  if ! ${DISABLE_GIT}; then
    # Check if the branch exists locally. If so, switch to it.
    if git rev-parse --verify "${GIT_BRANCH}" &> /dev/null; then
      echo "Branch ${GIT_BRANCH} exists locally. Switching to it."
      git checkout "${GIT_BRANCH}"

    # Otherwise, create it.
    else
      # Attempt to create the branch from its default CDE or CHUB branch name.
      echo "Branch ${GIT_BRANCH} does not exist locally"

      if git rev-parse --verify "${DEFAULT_CDE_BRANCH}" &> /dev/null; then
        # This block will be executed only during updates. At the time, we want to capture history
        # of all changes in the old CDE or customer-hub branches onto the new ones that are created.
        echo "Creating ${GIT_BRANCH} from its default branch ${DEFAULT_CDE_BRANCH}"
        git checkout -b "${GIT_BRANCH}" "${DEFAULT_CDE_BRANCH}"
      else
        # This block will be executed on initial seeding of the repo or if the default CDE branch does not
        # exist for some reason during an update. Our only option is to create it as an orphan branch.
        # If it's an update and we have access to the remote, then we'll pull the remote branch, if it
        # exists, onto the orphan branch in the following block.
        echo "Default branch ${DEFAULT_CDE_BRANCH} does not exist for branch ${GIT_BRANCH}"
        echo "Creating ${GIT_BRANCH} as an orphan branch"
        git checkout --orphan "${GIT_BRANCH}"
      fi
    fi
  fi

  # Check if the branch exists on remote. If so, pull the latest code from remote.
  if echo "${REMOTE_BRANCHES}" | grep -q "${GIT_BRANCH}" 2> /dev/null; then
    echo "Branch ${GIT_BRANCH} exists on server. Checking out latest code from server."
    git pull --no-edit origin "${GIT_BRANCH}" -X theirs
  elif ${DISABLE_GIT}; then
    echo "Not checking for branch in git, disabled by DISABLE_GIT"
  elif test "${REMOTE_BRANCHES}"; then
    echo "Branch ${GIT_BRANCH} does not exist on server."
  fi

  if "${IS_PRIMARY}"; then
    if is_all_apps; then
      # Clean-up everything in the repo.
      echo "Cleaning up ${PWD}"
      dir_deep_clean "${PWD}"
    else
      # Clean up only APPS_TO_PUSH directories
      for app in ${APPS_TO_PUSH}; do
        if "${IS_PROFILE_REPO}"; then
          echo "Cleaning up ${PWD}/${PROFILES_DIR}/${app}"
          dir_deep_clean "${PWD}/${PROFILES_DIR}/${app}"
        else
          echo "Cleaning up ${PWD}/${app}"
          dir_deep_clean "${PWD}/${app}"
        fi
      done
    fi

    if "${IS_PROFILE_REPO}" || "${INCLUDE_PROFILES_IN_CSR}"; then
      if is_all_apps; then
        # Copy the base files into the repo.
        src_dir="${GENERATED_CODE_DIR}/${PROFILE_REPO_DIR}"
        echo "Copying base files from ${src_dir} to ${PWD}"
        cp "${src_dir}"/.gitignore ./
        cp "${src_dir}"/upgrade-profile-wrapper.sh ./
      fi

      # Copy each app's profile files into the repo.
      for pr_app_path in ${APP_PATHS}; do
        pr_app_name=$(basename "${pr_app_path}")

        # Make the app dir
        mkdir -p "${PROFILES_DIR}/${pr_app_name}"

        # Copy the app profiles
        src_dir="${pr_app_path}"
        echo "Copying ${src_dir} to ${PROFILES_DIR}"
        cp -pr "${src_dir}" "${PROFILES_DIR}/"
      done
    fi

    if ! "${IS_PROFILE_REPO}"; then
      if is_all_apps; then
        # Copy the base files into the repo.
        src_dir="${GENERATED_CODE_DIR}/${CLUSTER_STATE_REPO_DIR}"
        echo "Copying base files from ${src_dir} to ${PWD}"
        cp "${src_dir}"/.gitignore ./
        cp "${src_dir}"/upgrade-cluster-state-wrapper.sh ./
        cp "${src_dir}"/csr-validation.sh ./
        cp "${src_dir}"/seal-secret-values.py ./
      fi

      # Copy each app's base files into the repo
      for app_path in ${APP_PATHS}; do
        app_name=$(basename "${app_path}")

        # Make the app dir
        mkdir -p "${app_name}"

        # Copy base files into the app directory.
        src_dir="${app_path}"
        echo "Copying base files from ${src_dir} to ${app_name}"
        find "${src_dir}" -type f -maxdepth 1 -exec cp {} "${app_name}" \;

        # Copy the base directory, which is common code for all regions.
        src_dir="${app_path}/${BASE_DIR}"
        echo "Copying ${src_dir} to ${app_name}"
        cp -pr "${src_dir}" "${app_name}/"
      done
    fi

    if is_all_apps; then
      # Last but not least, stick the version of Beluga into a version.txt file.
      beluga_version="$(find "${GENERATED_CODE_DIR}/${CLUSTER_STATE_REPO_DIR}/${ENV_OR_BRANCH}/${K8S_CONFIGS_DIR}" \
        -name env_vars -exec grep '^K8S_GIT_BRANCH=' {} \; | cut -d= -f2)"
      echo "Beluga version is ${beluga_version} for environment ${ENV}"
      echo "${beluga_version}" > version.txt
    fi
  fi

  if "${IS_PROFILE_REPO}"; then
    commit_msg="Initial commit of profile code for environment '${ENV}' - ping-cloud-base@${PCB_COMMIT_SHA}"
  else
    # Copy each app's region files into the repo
    for app_path in ${APP_PATHS}; do
      app_name=$(basename "${app_path}")

      # shellcheck disable=SC2010
      region_path="$(find "${app_path}" -mindepth 1 -maxdepth 1 -type d ! -path '*/base')"
      region=$(basename "${region_path}")
      src_dir="${app_path}/$region"

      # Make the app dir
      mkdir -p "${app_name}"

      echo "Copying ${src_dir} to ${app_name}"
      cp -pr "${src_dir}" "${app_name}/"
    done

    commit_msg="Initial commit of cluster state code for environment '${ENV}' in region '${region}' - ping-cloud-base@${PCB_COMMIT_SHA}"
  fi

  if ! ${DISABLE_GIT}; then
    echo "Adding commit to repo: ${commit_msg}"
    git add .
    git commit --allow-empty -m "${commit_msg}"
  fi

  if "${PUSH_TO_SERVER}" && ! "${DISABLE_GIT}"; then
    push_with_retries "${PUSH_RETRY_COUNT}" "${GIT_BRANCH}"
  else
    echo "Not pushing changes to the server for branch '${GIT_BRANCH}' - PUSH_TO_SERVER set to false or DISABLE_GIT set to true"
  fi

  if ! "${QUIET}"; then
    echo
    echo ---
    echo
  fi
done

# Run any required finalization
finalize