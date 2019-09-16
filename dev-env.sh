#!/bin/bash

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

# Show initial values for domain & environment
echo "Initial TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Initial ENVIRONMENT: ${ENVIRONMENT}"

# A script that may be used to set up a dev/test environment against the
# current cluster. Must have the GTE devops user and key exported as
# environment variables.
export ENVIRONMENT=-"${ENVIRONMENT:-${USER}}"
export TENANT_DOMAIN="${TENANT_DOMAIN:-eks-poc.au1.ping-lab.cloud}"

ENVIRONMENT_NO_HYPHEN_PREFIX=$(echo ${ENVIRONMENT/#-})

echo "Using TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Using ENVIRONMENT: ${ENVIRONMENT_NO_HYPHEN_PREFIX}"

NAMESPACE=ping-cloud-${ENVIRONMENT_NO_HYPHEN_PREFIX}
DEPLOY_FILE=/tmp/deploy.yaml

kustomize build test |
  envsubst '${PING_IDENTITY_DEVOPS_USER}
    ${PING_IDENTITY_DEVOPS_KEY}
    ${ENVIRONMENT}
    ${TENANT_DOMAIN}' > ${DEPLOY_FILE}
sed -i.bak -E "s/((namespace|name): )ping-cloud$/\1${NAMESPACE}/g" ${DEPLOY_FILE}

if [[ "${dryrun}" = 'false' ]]; then
  echo "Deploying ${DEPLOY_FILE} to namespace ${NAMESPACE} for tenant ${TENANT_DOMAIN}"
  kubectl apply -f ${DEPLOY_FILE}

  # Print out the ingress objects for logs and the ping stack
  kubectl get ingress -n elastic-stack-logging
  kubectl get ingress -n ${NAMESPACE}

  # Print out the  pods for the ping stack
  kubectl get pods -n ${NAMESPACE}
else
  less "${DEPLOY_FILE}"
fi
