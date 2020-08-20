#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

# Allow overriding the backup URL with an arg
test ! -z "${1}" && BACKUP_URL="${1}"
beluga_log "Uploading to location ${BACKUP_URL}"

# Set required environment variables for skbn
initializeSkbnConfiguration

# Create and export archive data into file data.mm-dd-YYYY.HH.MM.SS.zip
DST_FILE_TIMESTAMP="data-`date +%m-%d-%Y.%H.%M.%S`.zip"
DST_DIRECTORY="/tmp/k8s-s3-upload-archive"
mkdir -p ${DST_DIRECTORY}

beluga_log "waiting for admin API to be ready"
wait_for_admin_api_endpoint configArchive/export

# Make request to admin API and export latest data
make_api_request_download -X GET \
  "https://${PF_ADMIN_HOST_PORT}/pf-admin-api/v1/configArchive/export" \
  -o ${DST_DIRECTORY}/${DST_FILE_TIMESTAMP}

# Validate admin API call was successful and that zip isn't corrupted
if test ! $? -eq 0 || test "$( unzip -t ${DST_DIRECTORY}/${DST_FILE_TIMESTAMP} > /dev/null 2>&1;echo $?)" != "0" ; then
  beluga_log "Failed to export archive"
  # Cleanup k8s-s3-upload-archive temp directory
  rm -rf ${DST_DIRECTORY}
  exit 1
fi

# Two copy of the backup will be pushed to cloud storage.
# Make a copy: latest.zip
DST_FILE_LATEST="latest.zip"
UPLOAD_DIR="$(mktemp -d)"

cp "${DST_DIRECTORY}/$DST_FILE_TIMESTAMP" "${UPLOAD_DIR}/$DST_FILE_LATEST"
cp "${DST_DIRECTORY}/$DST_FILE_TIMESTAMP" "${UPLOAD_DIR}/$DST_FILE_TIMESTAMP"

beluga_log "Copying files to '${SKBN_CLOUD_PREFIX}'"

if ! skbnCopy "${SKBN_K8S_PREFIX}/${UPLOAD_DIR}/" "${SKBN_CLOUD_PREFIX}/"; then
  exit 1
fi

# STDOUT all the files in one line for integration test
ls ${UPLOAD_DIR} | xargs

# Cleanup k8s-s3-upload-archive temp directory
rm -rf ${DST_DIRECTORY}
rm -rf "${UPLOAD_DIR}"

exit 0
