#!/bin/bash

# A script that may be used to set up a dev/test environment against the
# current cluster. Must have the GTE devops user and key exported as
# environment variables.
export ENVIRONMENT="${ENVIRONMENT:--${USER}}"
export TENANT_DOMAIN="${TENANT_DOMAIN:-eks-poc.au1.ping-lab.cloud}"

ENVIRONMENT_NO_HYPHEN_PREFIX=$(echo ${ENVIRONMENT/#-})
NAMESPACE=ping-cloud-${ENVIRONMENT_NO_HYPHEN_PREFIX}
DEPLOY_FILE=/tmp/deploy.yaml

kustomize build test | envsubst > ${DEPLOY_FILE}
sed -i.bak -E "s/((namespace|name): )ping-cloud$/\1${NAMESPACE}/g" ${DEPLOY_FILE}

echo "Deploying ${DEPLOY_FILE} to namespace ${NAMESPACE} for tenant ${TENANT_DOMAIN}"
kubectl apply -f ${DEPLOY_FILE}

# Print out the ingress objects for logs and the ping stack
kubectl get ingress -n elastic-stack-logging
kubectl get ingress -n ${NAMESPACE}

# Print out the  pods for the ping stack
kubectl get pods -n ${NAMESPACE}