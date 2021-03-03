#!/bin/bash

# This script is a wrapper for the update-cluster-state.sh script and may be used to aid the operator in updating the
# cluster state repo to a target Beluga version. It abstracts away the location of the update-cluster-state.sh, which
# performs the actual cluster-state migration to a target Beluga version. The script must be run from the root of the
# cluster state repo clone directory in the following manner.
#
#     NEW_VERSION=${TARGET_VERSION} ./update-cluster-state-wrapper.sh
#
# For example:
#
#     NEW_VERSION=v1.7.1 ./update-cluster-state-wrapper.sh
#
# It acts on the following environment variables:
#
#     NEW_VERSION -> Required. The new version of Beluga to which to update the cluster state repo.
#     ENVIRONMENTS -> An optional space-separated list of environments. Defaults to 'dev test stage prod', if unset.
#         If provided, it must contain all or a subset of the environments currently created by the
#         generate-cluster-state.sh script, i.e. dev, test, stage, prod.
#     RESET_TO_DEFAULT -> An optional flag, which if set to true will reset the cluster-state-repo to the OOTB state
#         for the new version. This has the same effect as running the platform code build job.
#
# The script is non-destructive by design and doesn't push any new state to the server. Instead, it will set up a
# parallel branch for every CDE branch corresponding to the environments specified through the ENVIRONMENTS environment
# variable. For example, if the new version is v1.7.1, then it’ll set up 4 new branches at the new version for the
# default set of environments: v1.7.1-dev, v1.7.1-test, v1.7.1-stage and v1.7.1-master. These new branches will be valid
# for that version for all regions for the customer’s CDEs. A best faith effort will be made to migrate all existing
# customizations to server profiles and Kubernetes configuration. However, it’ll still be up to PS/GSO teams to verify
# that the migration is correct and complete. The update-cluster-state.sh script will provide further steps to the
# operator on how to complete the migration and test the new cluster state.

### Global variables and utility functions ###
PING_CLOUD_BASE='ping-cloud-base'
UPDATE_SCRIPT_NAME='update-cluster-state.sh'
CODE_GEN_DIR_NAME='code-gen'

########################################################################################################################
# Invokes pushd on the provided directory but suppresses stdout and stderr.
#
# Arguments
#   ${1} -> The directory to push.
########################################################################################################################
pushd_quiet() {
  # shellcheck disable=SC2164
  pushd "$1" >/dev/null 2>&1
}

########################################################################################################################
# Invokes popd but suppresses stdout and stderr.
########################################################################################################################
popd_quiet() {
  # shellcheck disable=SC2164
  popd >/dev/null 2>&1
}

### SCRIPT START ###

# Verify that required environment variable NEW_VERSION is set
if test -z "${NEW_VERSION}"; then
  echo '=====> NEW_VERSION environment variable must be set before invoking this script'
  exit 1
fi

# Clone ping-cloud-base at the new version, if necessary.
if ! test "${NEW_PING_CLOUD_BASE_REPO}"; then
  PCB_CLONE_BASE_DIR="$(mktemp -d)"
  PING_CLOUD_BASE_REPO_URL="${PING_CLOUD_BASE_REPO_URL:-$(git grep ^K8S_GIT_URL= | head -1 | cut -d= -f2)}"
  PING_CLOUD_BASE_REPO_URL="${PING_CLOUD_BASE_REPO_URL:-https://github.com/pingidentity/${PING_CLOUD_BASE}}"

  pushd_quiet "${PCB_CLONE_BASE_DIR}"
  echo "=====> Cloning ${PING_CLOUD_BASE}@${NEW_VERSION} from ${PING_CLOUD_BASE_REPO_URL} to '${PCB_CLONE_BASE_DIR}'"
  git clone -c advice.detachedHead=false --depth 1 --branch "${NEW_VERSION}" "${PING_CLOUD_BASE_REPO_URL}"
  if test $? -ne 0; then
    echo "=====> Unable to clone ${PING_CLOUD_BASE_REPO_URL}@${NEW_VERSION} from ${PING_CLOUD_BASE_REPO_URL}"
    popd_quiet
    exit 1
  fi
  popd_quiet

  NEW_PING_CLOUD_BASE_REPO="${PCB_CLONE_BASE_DIR}/${PING_CLOUD_BASE}"
fi

UPDATE_SCRIPT_PATH="${NEW_PING_CLOUD_BASE_REPO}/${CODE_GEN_DIR_NAME}/${UPDATE_SCRIPT_NAME}"

if test -f "${UPDATE_SCRIPT_PATH}"; then
  NEW_PING_CLOUD_BASE_REPO="${NEW_PING_CLOUD_BASE_REPO}" "${UPDATE_SCRIPT_PATH}"
  exit $?
else
  echo "=====> Upgrade script not supported to update the cluster state repo to version ${NEW_VERSION}"
  exit 1
fi
