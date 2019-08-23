#!/bin/bash

# Needs to have kubectl configured correctly to talk to a cluster.
# Must also have the PING_IDENTITY_DEVOPS_USER and PING_IDENTITY_DEVOPS_KEY
# environment variables obtained from the DevOps GTE team.

CONFIG_ROOT_DIR=/tmp/k8s-configs
DEVOPS_KEY_PASS_FILE=${CONFIG_ROOT_DIR}/ping-cloud/base/env_vars
CONFIG_FILE=/tmp/dev.yaml

rm -rf ${CONFIG_ROOT_DIR}
cp -pr ../k8s-configs /tmp

sed -i -e "s|@PING_IDENTITY_DEVOPS_USER@|${PING_IDENTITY_DEVOPS_USER}|" ${DEVOPS_KEY_PASS_FILE}
sed -i -e "s|@PING_IDENTITY_DEVOPS_KEY@|${PING_IDENTITY_DEVOPS_KEY}|" ${DEVOPS_KEY_PASS_FILE}

# Run kustomize build to validate the configurations
kustomize build ${CONFIG_ROOT_DIR} | tee ${CONFIG_FILE}
echo "[dev-env] config written to ${CONFIG_FILE}"

# Apply the configuration
echo "[dev-env] deploying dev environment"

# The kustomize included with kubectl is an older version. So this does not
# work right. For now, we'll just send the output of kustomize to kubectl.
# kubectl apply -k ${CONFIG_ROOT_DIR}
kubectl apply -f ${CONFIG_FILE}