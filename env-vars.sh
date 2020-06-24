#!/bin/bash
# Unset all env variables set previously
unset TENANT_NAME
unset TENANT_DOMAIN
unset REGION
unset SIZE
unset CLUSTER_NAME_LC
unset CLUSTER_STATE_REPO_URL
unset SSH_ID_PUB_FILE
unset SSH_ID_KEY_FILE
unset CONFIG_REPO_URL
unset CONFIG_REPO_BRANCH
unset CONFIG_PARENT_DIR
unset ARTIFACT_REPO_URL
unset LOG_ARCHIVE_URL
unset K8S_GIT_URL
unset K8S_GIT_BRANCH
unset REGISTRY_NAME
unset TARGET_DIR
unset IS_BELUGA_ENV
unset BACKUP_URL
# Re-assign all environment variables
export TENANT_NAME=geoff
export TENANT_DOMAIN=geoff.ping-demo.com
export REGION=us-west-2
export SIZE=small
export CONFIG_REPO_URL=https://github.com/pingidentity/ping-cloud-base.git
export CONFIG_PARENT_DIR=aws
#export CONFIG_REPO_BRANCH=master
# uncomment this env below if you are ever wanting to test your own branch than master
export CONFIG_REPO_BRANCH=$(git rev-parse --abbrev-ref HEAD)
#export ARTIFACT_REPO_URL=https://ping-artifacts.s3-us-west-2.amazonaws.com
export LOG_ARCHIVE_URL="s3://${TENANT_NAME}-test-cluster-csd-archives-bucket"
export BACKUP_URL=s3://${TENANT_NAME}-csd-archives-bucket
export ARTIFACT_REPO_URL=${BACKUP_URL}
export K8S_GIT_URL=https://github.com/pingidentity/ping-cloud-base
export K8S_GIT_BRANCH=master
export REGISTRY_NAME=docker.io
export IS_BELUGA_ENV=false
export IDENTITY_PUB_FILE="${HOME}/.ssh/id_rsa.pub"
export IDENTITY_KEY_FILE="${HOME}/.ssh/id_rsa"
