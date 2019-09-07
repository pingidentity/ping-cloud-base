#!/bin/bash

# A script that may be used to set up a dev/test environment against the
# current cluster. Must have the GTE devops user and key exported as
# environment variables.
NAMESPACE=ping-cloud-${USER}
export TENANT_DOMAIN="${TENANT_DOMAIN:-${USER}.eks-poc.au1.ping-lab.cloud}"

DEPLOY_FILE=/tmp/deploy.yaml

kustomize build test | envsubst > ${DEPLOY_FILE}
sed -i.bak -E "s/((namespace|name): )ping-cloud$/\1${NAMESPACE}/g" ${DEPLOY_FILE}

echo "Deploying ${DEPLOY_FILE} to namespace ${NAMESPACE} for tenant ${TENANT_DOMAIN}"
kubectl apply -f ${DEPLOY_FILE}

kubectl get ingress -n ${NAMESPACE}