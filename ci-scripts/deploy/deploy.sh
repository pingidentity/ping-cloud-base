#!/bin/bash
set -e

test "${VERBOSE}" && set -x

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

configure_aws
configure_kube

pushd "${PROJECT_DIR}"

# Deploy the configuration to Kubernetes
if [[ -n ${PINGONE} ]]; then
  set_pingone_api_env_vars
  pip3 install -r ${PROJECT_DIR}/ci-scripts/deploy/ping-one/requirements.txt
  log "Deleting P1 Environment if it already exists"
  python3 ${PROJECT_DIR}/ci-scripts/deploy/ping-one/p1_env_setup_and_teardown.py Teardown 2>/dev/null || true
  log "Creating P1 Environment"
  python3 ${PROJECT_DIR}/ci-scripts/deploy/ping-one/p1_env_setup_and_teardown.py Setup
fi

deploy_file=/tmp/deploy.yaml

# Apply Custom Resource Definitions separate, due to size, if applicable
apply_crds "${PROJECT_DIR}"

# Build file while cert-manager webhook service coming up to save time
build_dev_deploy_file "${deploy_file}"

kubectl apply -f "${deploy_file}"

check_if_ready "${PING_CLOUD_NAMESPACE}"

popd  > /dev/null 2>&1
