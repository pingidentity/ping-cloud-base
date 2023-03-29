#!/bin/bash
set -e

test "${VERBOSE}" && set -x

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

configure_kube

pushd "${PROJECT_DIR}"

# Deploy the configuration to Kubernetes
pip_install_shared_pingone_scripts
log "Deleting P1 resources created by deployment if they already exist"
p1_deployment_cleanup
log "Deleting P1 Environment if it already exists"
cicd_p1_env_setup_and_teardown Teardown 2>/dev/null || true
log "Creating P1 Environment"
cicd_p1_env_setup_and_teardown Setup

deploy_file=/tmp/deploy.yaml

#clean up the previous deployment dns rcords before deploying
delete_dns_records "${TENANT_DOMAIN}"

# Apply Custom Resource Definitions separate, due to size, if applicable
apply_crds "${PROJECT_DIR}"

# Build file while cert-manager webhook service coming up to save time
build_dev_deploy_file "${deploy_file}"

kubectl apply -f "${deploy_file}"

check_if_ready "${PING_CLOUD_NAMESPACE}"

popd  > /dev/null 2>&1
