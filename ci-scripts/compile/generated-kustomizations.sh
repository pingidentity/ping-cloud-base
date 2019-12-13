#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

# Generate the code first
export TARGET_DIR=/tmp/sanbbox
export TENANT_DOMAIN="${EKS_CLUSTER_NAME}"

${CI_PROJECT_DIR}/code-gen/generate-cluster-state.sh

# Verify that all kustomizations are able to be built
build_kustomizations_in_dir "${TARGET_DIR}"
exit ${?}