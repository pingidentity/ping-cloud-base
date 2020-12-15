#!/bin/bash

# This script may be used to upgrade an existing cluster state repo. It is designed to be non-destructive in that it
# won't push the changes to the server before confirming with the user. However, it will replace the contents of the
# remote branches corresponding to the different Customer Deployment Environments with the new state.

# NOTE: This script must be run from the root of the cluster state repo clone directory. It acts on the following
# environment variables.
#
#   ENVIRONMENTS -> A space-separated list of environments. Defaults to 'dev test stage prod', if unset. If provided,
#       it must contain all or a subset of the environments currently created by the generate-cluster-state.sh script,
#       i.e. dev, test, stage, prod.

### Global variables and utility functions ###
K8S_CONFIGS_DIR='k8s-configs'
BASE_DIR='base'
ENV_VARS_FILE_NAME='env_vars'
PING_CLOUD_BASE='ping-cloud-base'
CLUSTER_STATE_REPO='cluster-state-repo'

########################################################################################################################
# Invokes pushd on the provided directory but suppresses stdout and stderr.
#
# Arguments
#   ${1} -> The directory to push.
########################################################################################################################
pushd_quiet() {
  set -e; pushd "$1" >/dev/null 2>&1; set +e
}

########################################################################################################################
# Invokes popd but suppresses stdout and stderr.
########################################################################################################################
popd_quiet() {
  set -e; popd >/dev/null 2>&1; set +e
}

########################################################################################################################
# Sets the name-value pairs in the provided file as environment variables.
#
# Arguments
#   ${1} -> The environment variables file.
########################################################################################################################
set_env_vars() {
  set -a
  # shellcheck disable=SC1090
  source "$1"
  set +a
}

### SCRIPT START ###

# Ensure that this script works from any working directory
SCRIPT_HOME=$(cd "$(dirname "$0")" 2>/dev/null; pwd)
pushd_quiet "${SCRIPT_HOME}"

# Verify that required environment variable NEW_VERSION is set
if test -z "${NEW_VERSION}"; then
  echo '=====> NEW_VERSION environment variable must be set before invoking this script'
  exit 1
fi

# Perform some basic validation of the cluster state repo
ALL_ENVIRONMENTS='dev test stage prod'
ENVIRONMENTS="${ENVIRONMENTS:-${ALL_ENVIRONMENTS}}"

NEW_BRANCHES=
REPO_STATUS=0

echo "=====> Validating that '${CLUSTER_STATE_REPO}' has branches for environments: '${ENVIRONMENTS}'"

for ENV in ${ENVIRONMENTS}; do
  test "${ENV}" = 'prod' &&
      BRANCH='master' ||
      BRANCH="${ENV}"

  echo "=====> Validating that '${CLUSTER_STATE_REPO}' has branch: '${BRANCH}'"
  git checkout "${BRANCH}" > /dev/null 2>&1
  if test $? -ne 0; then
    echo "=====> CDE branch '${BRANCH}' does not exist in '${CLUSTER_STATE_REPO}'"
    REPO_STATUS=1
  fi

  if test ! -d "${K8S_CONFIGS_DIR}"; then
    echo '=====> This script must be run from the base directory of the cluster state repo that is being upgraded'
    REPO_STATUS=1
  fi

  NEW_BRANCH="${NEW_VERSION}-${BRANCH}"
  test "${NEW_BRANCHES}" &&
      NEW_BRANCHES="${NEW_BRANCHES} ${NEW_BRANCH}" ||
      NEW_BRANCHES="${NEW_BRANCH}"
done

test "${REPO_STATUS}" -ne 0 && exit 1

# Clone ping-cloud-base at the new version
NEW_CLUSTER_STATE_REPO="$(mktemp -d)"
PING_CLOUD_BASE_REPO_URL=https://github.com/minigans/ping-cloud-base

pushd_quiet "${NEW_CLUSTER_STATE_REPO}"
echo "=====> Cloning ${PING_CLOUD_BASE}@${NEW_VERSION} from ${PING_CLOUD_BASE_REPO_URL} to '${NEW_CLUSTER_STATE_REPO}'"
git clone --depth 1 --branch "${NEW_VERSION}" "${PING_CLOUD_BASE_REPO_URL}"
if test $? -ne 0; then
  echo "=====> Unable to clone ${PING_CLOUD_BASE_REPO_URL}@${NEW_VERSION} from ${PING_CLOUD_BASE_REPO_URL}"
  exit 1
fi
popd_quiet

# Generate cluster state code for new version

# NOTE: This entire block of code is being run from the cluster-state-repo directory. All non-absolute paths are
# relative to this directory.

# Switch to the master branch - the environment variables are mostly the same across CDEs. The only differences are
# the ones that generate-cluster-state.sh already knows how to handle when it's provided with the expected environmnet
# variables.
git checkout master > /dev/null 2>&1

# Get the names of all the regional directories. Note this may not be the actual region, rather it's the nick name of
# the region.
REGION_DIRS="$(find "${K8S_CONFIGS_DIR}" \
    -mindepth 1 -maxdepth 1 \
    -type d \( ! -name "${BASE_DIR}" \) \
    -exec basename {} \;)"
echo "=====> '${CLUSTER_STATE_REPO}' has the following region directories:"
echo "${REGION_DIRS}"

# The base environment variables file that's common to all regions
BASE_ENV_VARS="${K8S_CONFIGS_DIR}/${BASE_DIR}/${ENV_VARS_FILE_NAME}"

# Code for this customer will be generated in the following directory. Each region will get its own sub-directory
# under this directory.
TENANT_CODE_DIR="$(mktemp -d)"

# The file into which the primary region directory name will be stored for later use
PRIMARY_REGION_DIR_FILE="$(mktemp)"

for REGION_DIR in ${REGION_DIRS}; do
  # Perform the code generation in a sub-shell so it doesn't pollute the current shell
  (
    REGION_ENV_VARS="${K8S_CONFIGS_DIR}/${REGION_DIR}/${ENV_VARS_FILE_NAME}"
    ENV_VARS_FILES="$(find "${K8S_CONFIGS_DIR}/${REGION_DIR}" -type f -mindepth 2 -name "${ENV_VARS_FILE_NAME}")"

    # Set the environment variables in the order: region-specific, app-specific (within the region directories),
    # base. This will ensure that derived variables are set correctly.
    set_env_vars "${REGION_ENV_VARS}"
    for ENV_VARS_FILE in ${ENV_VARS_FILES}; do
      set_env_vars "${ENV_VARS_FILE}"
    done
    set_env_vars "${BASE_ENV_VARS}"

    # Special-case a few variables
    export TARGET_DIR="${TENANT_CODE_DIR}/${REGION_DIR}"
    export TENANT_NAME='ping-cloud-customer'
    export SIZE="${KUSTOMIZE_BASE#*/}"
    export K8S_GIT_BRANCH="${NEW_VERSION}"

    # Generate code now that we have set all the required environment variables
    echo "=====> Generating code for region '${REGION_DIR}' into '${TARGET_DIR}' for branches '${NEW_BRANCHES}'"
    ENVIRONMENTS="${NEW_BRANCHES}" "${NEW_CLUSTER_STATE_REPO}/${PING_CLOUD_BASE}"/code-gen/generate-cluster-state.sh
    echo "=====> Done generating code for region '${REGION_DIR}' into '${TARGET_DIR}' for branches '${NEW_BRANCHES}'"

    # Persist the primary region's directory name for later use
    if test "${TENANT_DOMAIN}" = "${PRIMARY_TENANT_DOMAIN}"; then
      echo "${REGION_DIR}" > "${PRIMARY_REGION_DIR_FILE}"
    fi
  )
done

PRIMARY_REGION_DIR="$(cat "${PRIMARY_REGION_DIR_FILE}")"
if test "${PRIMARY_REGION_DIR}"; then
  echo "=====> Primary region directory for customer: '${PRIMARY_REGION_DIR}'"
else
  echo "=====> Primary region is unknown for customer"
  exit 1
fi

# Sort the regions such that the primary region is first in order
REGION_DIRS_SORTED="${PRIMARY_REGION_DIR}"
for REGION_DIR in ${REGION_DIRS}; do
  test "${PRIMARY_REGION_DIR}" != "${REGION_DIR}" &&
      REGION_DIRS_SORTED="${REGION_DIRS_SORTED} ${REGION_DIR}"
done

echo "=====> Region directories in sorted order: ${REGION_DIRS_SORTED}"
for REGION_DIR in ${REGION_DIRS_SORTED}; do
  if test "${PRIMARY_REGION_DIR}" = "${REGION_DIR}"; then
    IS_PRIMARY=true
    TYPE='primary'
  else
    IS_PRIMARY=false
    TYPE='secondary'
  fi

  TARGET_DIR="${TENANT_CODE_DIR}/${REGION_DIR}"
  echo "=====> Generated code directory for ${TYPE} region '${REGION_DIR}': ${TARGET_DIR}"

  echo "=====> Creating branches for ${TYPE} region '${REGION_DIR}' : ${NEW_BRANCHES}"
  GENERATED_CODE_DIR="${TARGET_DIR}" \
      IS_PRIMARY=${IS_PRIMARY} \
      ENVIRONMENTS="${NEW_BRANCHES}" \
      PUSH_TO_SERVER=false \
      "${NEW_CLUSTER_STATE_REPO}/${PING_CLOUD_BASE}"/code-gen/push-cluster-state.sh
  echo "=====> Done creating branches for ${TYPE} region '${REGION_DIR}': ${NEW_BRANCHES}"
done

# Go back to previous git branch and working directory
git checkout - > /dev/null 2>&1
popd_quiet