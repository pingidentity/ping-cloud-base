#!/bin/bash

# This script is the working area for secret update hooks.
# The script must be run from the root of the cluster state repo clone directory in the following manner:
# ./update-cluster-secrets.sh

# CLUSTER_STATE_REPO='cluster-state-repo'
K8S_CONFIGS='k8s-configs'
BASE='base'
SECRETS_FILE_NAME='secrets.yaml'
ENV_VARS_FILE_NAME='env_vars'
SEALED_SECRETS_FILE_NAME='sealed-secrets.yaml'
PING_CLOUD_DEFAULT_DEVOPS_USER='pingcloudpt-licensing@pingidentity.com'

update_pingfederate_secrets() {
    SECRET_FILE="$K8S_CONFIGS/$BASE/$SECRETS_FILE_NAME"
    ENV_VARS_FILE="$K8S_CONFIGS/$BASE/$ENV_VARS_FILE_NAME"
    # TODO: need to branch and name based on customer branch
    git checkout -b customer-secret-update-staging
    # TODO: placeholder for however we get the password
    NEW_SECRET=$(openssl rand -base64 32)
    # TODO: what if it isnt set yet?
    sed -e "s/PF_ADMIN_USER_PASSWORD=*/PF_ADMIN_USER_PASSWORD=$NEW_SECRET/" $SECRET_FILE
    # seal
    sed -e "s/LAST_UPDATE_REASON=*/LAST_UPDATE_REASON=password rolled/" $ENV_VARS_FILE
    git add .
    git commit -m “update secret”
    git checkout master
    git merge customer-secret-update-staging
    git branch -D customer-secret-update-staging
}

update_pingfederate_secrets