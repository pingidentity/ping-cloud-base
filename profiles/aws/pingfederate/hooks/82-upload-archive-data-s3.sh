#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

set -x 

test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"

# Allow overriding the backup URL with an arg
test ! -z "${1}" && BACKUP_URL="${1}"
echo "Uploading to location ${BACKUP_URL}"

# Set required environment variables for skbn
initializeSkbnConfiguration

# Create and export archive data into file data.mm-dd-YYYY.HH.MM.SS.zip
DST_FILE_TIMESTAMP="data-`date +%m-%d-%Y.%H.%M.%S`.zip"
DST_DIRECTORY="/tmp/k8s-s3-upload-archive"
mkdir -p ${DST_DIRECTORY}

# Make request to admin API and export latest data
make_api_request -X GET \
  https://localhost:${PINGFEDERATE_ADMIN_PORT}/pf-admin-api/v1/configArchive/export \
  -o ${DST_DIRECTORY}/${DST_FILE_TIMESTAMP}

# Validate admin API call was successful and that zip isn't corrupted
if test ! $? -eq 0 || test "$( unzip -t ${DST_DIRECTORY}/${DST_FILE_TIMESTAMP} > /dev/null 2>&1;echo $?)" != "0" ; then
  echo "Failed to export archive"
  # Cleanup k8s-s3-upload-archive temp directory
  rm -rf ${DST_DIRECTORY}
  exit 1
fi

# Two copy of the backup will be pushed to cloud storage.
# Make a copy: latest.zip
DST_FILE_LATEST=latest.zip
cp "${DST_DIRECTORY}/$DST_FILE_TIMESTAMP" "${DST_DIRECTORY}/$DST_FILE_LATEST" 

echo "Copying: '${DST_FILE_LATEST}' to '${SKBN_CLOUD_PREFIX}/${DST_FILE_LATEST}'"

if ! skbnCopy "${SKBN_K8S_PREFIX}/${DST_DIRECTORY}/${DST_FILE_LATEST}" \
  "${SKBN_CLOUD_PREFIX}/${DST_FILE_LATEST}"; then
  exit 1
fi

echo "Copying: '${DST_FILE_TIMESTAMP}' to '${SKBN_CLOUD_PREFIX}/${DST_FILE_TIMESTAMP}'"

if ! skbnCopy "${SKBN_K8S_PREFIX}/${DST_DIRECTORY}/${DST_FILE_TIMESTAMP}" \
  "${SKBN_CLOUD_PREFIX}/${DST_FILE_TIMESTAMP}"; then
  exit 1
fi

# Print listed files from k8s-s3-upload-archive
ls ${DST_DIRECTORY}

# Cleanup k8s-s3-upload-archive temp directory
rm -rf ${DST_DIRECTORY}

exit 0