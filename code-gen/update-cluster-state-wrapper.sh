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
UPDATE_SCRIPT_NAME='update-cluster-state.sh'
CODE_GEN_DIR_NAME='code-gen'

### SCRIPT START ###

# Verify that required environment variable NEW_VERSION is set
if test -z "${NEW_PING_CLOUD_BASE_REPO}"; then
  echo '=====> NEW_PING_CLOUD_BASE_REPO environment variable must be set before invoking this script'
  exit 1
fi

NEW_VERSION=1.7.0 "${NEW_PING_CLOUD_BASE_REPO}/${CODE_GEN_DIR_NAME}/${UPDATE_SCRIPT_NAME}"
exit $?