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

# Add code below to execute upload-artifact.sh script to upload Standard IKs
# Example to upload an artifact
#./upload-artifact.sh ${ARTIFACT_SOURCE_URL}/products/plugins/integration-kits/<name-of-the-integration-kit>/<name-of-the-integration-kit>/<version>/<name-of-the-integration-kit-version.zip>
