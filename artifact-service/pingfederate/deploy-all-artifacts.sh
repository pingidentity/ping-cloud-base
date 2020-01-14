#!/usr/bin/env sh

${VERBOSE} && set -x
source ./util.sh

# Set PATH - since this is executed from within the server process, it may not have all we need on the path
export PATH="${PATH}:${SERVER_ROOT_DIR}/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${JAVA_HOME}/bin"

# Allow overriding the Artifact Repo Bucket with an arg
test ! -z "${1}" && ARTIFACT_REPO_BUCKET="${1}"

if test -z "${ARTIFACT_REPO_BUCKET}"; then
  echo "ARTIFACT_REPO_BUCKET needs to be specified as an environment variable or as the first argument to this script"
  exit 0
else
  export ARTIFACT_REPO_BUCKET=${ARTIFACT_REPO_BUCKET}
fi

# Install AWS CLI if the upload location is S3
if test "${ARTIFACT_REPO_BUCKET#s3}" == "${ARTIFACT_REPO_BUCKET}"; then
    echo "Upload location is not S3"
    exit 0
elif ! which aws > /dev/null; then
    echo "Installing AWS CLI"
    apk --update add python3
    pip3 install --no-cache-dir --upgrade pip
    pip3 install --no-cache-dir --upgrade awscli
fi

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/products/integration-kits/pf-rsa-securid-integration-kit/3.0.1/pf-rsa-securid-integration-kit-3.0.1.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/products/plugins/integration-kits/pf-iovation-integration-kit/pf-iovation-integration-kit/1.0/pf-iovation-integration-kit-1.0.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/products/plugins/p14c-plugins/pf-p14c-integration-kit/1.2.1/pf-p14c-integration-kit-1.2.1.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/products/plugins/integration-kits/pf-github-cloud-identity-connector/pf-github-cloud-identity-connector/1.0/pf-github-cloud-identity-connector-1.0.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/com/pingidentity/adapters/pf-airwatch-adapter/1.0.2/pf-airwatch-adapter-1.0.2.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/products/plugins/integration-kits/pf-atlassian-integration-kit/pf-atlassian-integration-kit/2.1/pf-atlassian-integration-kit-2.1.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/products/plugins/cloud-identity-connectors/pf-google-cloud-identity-connector/pf-google-cloud-identity-connector/1.4.1/pf-google-cloud-identity-connector-1.4.1.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/products/pf-adapters/products/plugins/cloud-identity-connectors/pf-openid-cloud-identity-connector/pf-openid-cloud-identity-connector/1.3.2/pf-openid-cloud-identity-connector-1.3.2.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/com/pingidentity/adapters/duo/pf-duo-security-integration-kit/2.2.1/pf-duo-security-integration-kit-2.2.1.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/products/plugins/integration-kits/pf-amazon-cloud-identity-connector/pf-amazon-cloud-identity-connector/1.0/pf-amazon-cloud-identity-connector-1.0.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/products/plugins/integration-kits/pf-vip-integration-kit/pf-vip-integration-kit/1.4.0/pf-vip-integration-kit-1.4.0.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/products/plugins/integration-kits/pf-x509-certificate-integration-kit/pf-x509-certificate-integration-kit/1.2.1/pf-x509-certificate-integration-kit-1.2.1.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/com/pingidentity/integrations/mobileiron-ik/1.0.0/mobileiron-ik-1.0.0.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/products/plugins/cloud-identity-connectors/pf-facebook-cloud-identity-connector/pf-facebook-cloud-identity-connector/2.0.1/pf-facebook-cloud-identity-connector-2.0.1.zip

./upload-pf-artifact.sh https://art01.corp.pingidentity.com/artifactory/libs-releases-local/products/plugins/integration-kits/pf-apple-cloud-identity-connector/pf-apple-cloud-identity-connector/1.0.1/pf-apple-cloud-identity-connector-1.0.1.zip
