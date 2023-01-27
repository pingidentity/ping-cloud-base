#!/bin/bash

echo "Attempting to update the AWS Systems Manager configuration..."

profile=${AWS_PROFILE:-'csg-beluga'}
region=${REGION:-'us-west-2'}

if [[ $PINGCLOUD_CLIENT_ID == "" ]]; then
    echo "Environment variables not set, make sure you set them in .env and source the file prior to running"
    exit 1
fi

# TODO: we must make sure CLUSTER_NAME is set and make it the only option for the path
# to match Terraform changes in: ping-cloud-tools/create-cluster/terraform/ssm.tf
param_store_path_base="/${CLUSTER_NAME:-${USER}}/pcpt/orch-api"

# Product Entitlements SSM Param for legacy (pre 1.13) deployments
legacy_product_entitlements_path="${param_store_path_base}/product-entitlements"

product_entitlements_path="${param_store_path_base}/product-entitlements/v2"

entitlements_value=$(cat <<EOF
{
  "productEntitlements": ${PRODUCT_ENTITLEMENTS}
}
EOF)

echo "Updating the legacy entitlements parameter..."
aws ssm put-parameter \
    --name "${legacy_product_entitlements_path}" \
    --value "${entitlements_value}" \
    --type String \
    --region "${region}" \
    --profile "${profile}" \
    --overwrite

echo "Updating the entitlements parameter..."
aws ssm put-parameter \
    --name "${product_entitlements_path}" \
    --value "${entitlements_value}" \
    --type String \
    --region "${region}" \
    --profile "${profile}" \
    --overwrite


bootstrap_config_path="${param_store_path_base}/bootstrap-configuration"
bootstrap_value=$(cat <<EOF
{
  "bootstrapConfiguration": {
    "clientId": "${PINGCLOUD_CLIENT_ID}",
    "clientSecret": "${PINGCLOUD_CLIENT_SECRET}",
    "clientAuthenticationType": "client_secret_basic",
    "issuerUri": "https://auth-staging.pingone.com/as",
    "scopes": "openid email"
  }
}
EOF)

echo "Updating the bootstrap configuration parameter..."
aws ssm put-parameter \
    --name "${bootstrap_config_path}" \
    --value "${bootstrap_value}" \
    --type "SecureString" \
    --region "${region}" \
    --profile "${profile}" \
    --overwrite


environment_metadata_config_path="${param_store_path_base}/environment-metadata"
environment_metadata_value=$(cat <<EOF
{
    "pingOneInformation": {
      "organizationId": "${ORG_ID}",
      "webhookBaseUrl": "https://api-staging.pingone.com",
      "environmentId": "${ENV_ID}",
      "deploymentIds": ${DEPLOYMENT_IDS},
      "environmentType": "dev"
    }
}
EOF)

echo "Updating a environment metadata parameter..."
aws ssm put-parameter \
    --name "${environment_metadata_config_path}" \
    --value "${environment_metadata_value}" \
    --type "String" \
    --region "${region}" \
    --profile "${profile}" \
    --overwrite


is_pingone_config_path="${param_store_path_base}/is-myping"

echo "Updating the is PingOne string parameter..."
aws ssm put-parameter \
    --name "${is_pingone_config_path}" \
    --value "true" \
    --type "String" \
    --region "${region}" \
    --profile "${profile}" \
    --overwrite


unset profile
unset region
