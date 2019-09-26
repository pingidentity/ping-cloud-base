#!/bin/bash

# Source some utility methods.
. utils.sh

declare dryrun="false"

# Parse Parameters
while getopts 'n' OPTION
do
  case ${OPTION} in
    n)
      dryrun='true'
      ;;
    *)
      echo "Usage ${0} [ -n ] n = dry-run"
      exit 1
      ;;
  esac
done

# Checking required tools and environment variables.
HAS_REQUIRED_TOOLS=$(check_binaries "openssl" "base64" "envsubst"; echo ${?})
HAS_REQUIRED_VARS=$(check_env_vars "PING_IDENTITY_DEVOPS_USER" "PING_IDENTITY_DEVOPS_KEY"; echo ${?})

if test ${HAS_REQUIRED_TOOLS} -ne 0 || test ${HAS_REQUIRED_VARS} -ne 0; then
  exit 1
fi

# Show initial values for relevant environment variables.
echo "Initial ENVIRONMENT: ${ENVIRONMENT}"
echo "Initial TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Initial CLUSTER_NAME: ${CLUSTER_NAME}"
echo "Initial REGION: ${REGION}"

# A script that may be used to set up a dev/test environment against the
# current cluster. Must have the GTE devops user and key exported as
# environment variables.
export ENVIRONMENT=-"${ENVIRONMENT:-${USER}}"
export TENANT_DOMAIN="${TENANT_DOMAIN:-eks-poc.au1.ping-lab.cloud}"
export CLUSTER_NAME="${TENANT_NAME:-PingPOC}"
export REGION="${REGION:-us-east-2}"

ENVIRONMENT_NO_HYPHEN_PREFIX=$(echo ${ENVIRONMENT/#-})

echo "Using TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Using ENVIRONMENT: ${ENVIRONMENT_NO_HYPHEN_PREFIX}"
echo "Using CLUSTER_NAME: ${CLUSTER_NAME}"
echo "Using REGION: ${REGION}"

NAMESPACE=ping-cloud-${ENVIRONMENT_NO_HYPHEN_PREFIX}
DEPLOY_FILE=/tmp/deploy.yaml

# Generate a self-signed cert for the tenant domain.
generate_tls_cert "${TENANT_DOMAIN}"

kustomize build test |
  envsubst '${PING_IDENTITY_DEVOPS_USER}
    ${PING_IDENTITY_DEVOPS_KEY}
    ${ENVIRONMENT}
    ${TENANT_DOMAIN}
    ${CLUSTER_NAME}
    ${REGION}
    ${TLS_CRT_BASE64}
    ${TLS_KEY_BASE64}' > ${DEPLOY_FILE}
sed -i.bak -E "s/((namespace|name): )ping-cloud$/\1${NAMESPACE}/g" ${DEPLOY_FILE}

if test "${dryrun}" = 'false'; then
  echo "Deploying ${DEPLOY_FILE} to namespace ${NAMESPACE} for tenant ${TENANT_DOMAIN}"
  kubectl apply -f ${DEPLOY_FILE}

  # Print out the ingress objects for logs and the ping stack
  kubectl get ingress -A

  # Describe the LB service for pingdirectory
  kubectl describe svc pingdirectory-admin -n ${NAMESPACE}

  # Print out the  pods for the ping stack
  kubectl get pods -n ${NAMESPACE}
else
  less "${DEPLOY_FILE}"
fi