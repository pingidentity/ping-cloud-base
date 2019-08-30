#!/bin/sh
set -ex

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

# Kubernetes variables
KUBECONFIG=${CI_PROJECT_DIR}/kubeconfig

# AWS variables
AWS_REGION=us-west-2
AWS_ACCOUNT_ID=705370621539
AWS_ROLE_NAME=CSG
AWS_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${AWS_ROLE_NAME}"
AWS_CONFIG_DIR="/root/.aws"
AWS_CONFIG_FILE="${AWS_CONFIG_DIR}/config"
AWS_CREDENTIALS_FILE="${AWS_CONFIG_DIR}/credentials"

# Create the AWS config file to use the specific IAM role
mkdir -p "${AWS_CONFIG_DIR}"
echo '[default]' > "${AWS_CONFIG_FILE}"
echo 'output = json' >> "${AWS_CONFIG_FILE}"
echo "region = ${AWS_REGION}" >> "${AWS_CONFIG_FILE}"
echo '[profile gte]' >> "${AWS_CONFIG_FILE}"
echo "region = ${AWS_REGION}" >> "${AWS_CONFIG_FILE}"
echo 'source_profile = default' >> "${AWS_CONFIG_FILE}"
echo "role_arn = ${AWS_ROLE_ARN}" >> "${AWS_CONFIG_FILE}"

# Create the AWS credentials file to use the specific IAM role
echo '[default]' > "${AWS_CREDENTIALS_FILE}"
echo "aws_access_key_id = ${AWS_ACCESS_KEY_ID}" >> "${AWS_CREDENTIALS_FILE}"
echo "aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}" >> "${AWS_CREDENTIALS_FILE}"
echo "role_arn = ${AWS_ROLE_ARN}" >> "${AWS_CREDENTIALS_FILE}"

# Deploy to Kubernetes
log "Deploying config under ${CI_PROJECT_DIR}/test"
cd  ${CI_PROJECT_DIR}/test
kustomize build | envsubst | kubectl apply -f -