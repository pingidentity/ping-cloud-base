#!/bin/sh

${VERBOSE} && set -x

# Allow overriding the Artifact Repo Bucket with an arg
test ! -z "${1}" && ARTIFACT_REPO_BUCKET="${1}"

# Allow overriding the Artifact Source with an arg
test ! -z "${2}" && ARTIFACT_SOURCE_URL="${2}"

if test -z "${ARTIFACT_REPO_BUCKET}"; then
  echo "ARTIFACT_REPO_BUCKET needs to be specified as an environment variable or as the first argument to this script"
  exit 0
else
  export ARTIFACT_REPO_BUCKET=${ARTIFACT_REPO_BUCKET}
fi

if test -z "${ARTIFACT_SOURCE_URL}"; then
  export ARTIFACT_SOURCE_URL="https://art01.corp.pingidentity.com/artifactory/libs-releases-local"
fi

ARTIFACT_VISIBILITY=public
export ARTIFACT_VISIBILITY=${ARTIFACT_VISIBILITY}

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/integration-kits/pf-rsa-securid-integration-kit/3.0.1/pf-rsa-securid-integration-kit-3.0.1.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/plugins/integration-kits/pf-iovation-integration-kit/pf-iovation-integration-kit/1.0/pf-iovation-integration-kit-1.0.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/plugins/p14c-plugins/pf-p14c-integration-kit/1.2.1/pf-p14c-integration-kit-1.2.1.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/plugins/integration-kits/pf-github-cloud-identity-connector/pf-github-cloud-identity-connector/1.0/pf-github-cloud-identity-connector-1.0.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/com/pingidentity/adapters/pf-airwatch-adapter/1.0.2/pf-airwatch-adapter-1.0.2.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/plugins/cloud-identity-connectors/pf-google-cloud-identity-connector/pf-google-cloud-identity-connector/1.4.1/pf-google-cloud-identity-connector-1.4.1.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/com/pingidentity/adapters/duo/pf-duo-security-integration-kit/2.2.1/pf-duo-security-integration-kit-2.2.1.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/plugins/integration-kits/pf-amazon-cloud-identity-connector/pf-amazon-cloud-identity-connector/1.0/pf-amazon-cloud-identity-connector-1.0.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/plugins/integration-kits/pf-vip-integration-kit/pf-vip-integration-kit/1.4.0/pf-vip-integration-kit-1.4.0.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/plugins/integration-kits/pf-x509-certificate-integration-kit/pf-x509-certificate-integration-kit/1.2.1/pf-x509-certificate-integration-kit-1.2.1.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/com/pingidentity/integrations/mobileiron-ik/1.0.0/mobileiron-ik-1.0.0.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/plugins/cloud-identity-connectors/pf-facebook-cloud-identity-connector/pf-facebook-cloud-identity-connector/2.0.1/pf-facebook-cloud-identity-connector-2.0.1.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/plugins/integration-kits/pf-apple-cloud-identity-connector/pf-apple-cloud-identity-connector/1.0.1/pf-apple-cloud-identity-connector-1.0.1.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/com/pingidentity/clientservices/product/coreblox/coreblox-integration-kit/2.6.1/coreblox-integration-kit-2.6.1.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/com/pingidentity/saas/products/plugins/pf-aws-connector/pf-aws-connector/2.0/pf-aws-connector-2.0.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/plugins/integration-kits/pf-agentless-integration-kit/pf-agentless-integration-kit/1.5.2/pf-agentless-integration-kit-1.5.2.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/SampleApplications/oauth/OAuthPlayground/4.2/OAuthPlayground-4.2.zip

./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/plugins/integration-kits/pf-id-dataweb-integration-kit/pf-id-dataweb-integration-kit/1.0/pf-id-dataweb-integration-kit-1.0.zip

