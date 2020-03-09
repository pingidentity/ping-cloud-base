#!/bin/sh
set -e

. "${HOOKS_DIR}/utils.lib.sh"

# Install AWS CLI and set required environment variables for AWS S3 bucket
initializeS3Configuration

# This is the backup directory on the server
SERVER_BACKUP_DIR="${OUT_DIR}/backup"

rm -rf "${SERVER_BACKUP_DIR}"
mkdir -p "${SERVER_BACKUP_DIR}"

echo "Doing a full backup of ${USER_BACKEND_ID} backend to ${SERVER_BACKUP_DIR}"
backup --task \
  --useSSL --trustAll \
  --port ${LDAPS_PORT} \
  --bindDN "${ROOT_USER_DN}" \
  --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
  --backupDirectory "${SERVER_BACKUP_DIR}" \
  --backendID "${USER_BACKEND_ID}" \
  --compress

# Zip backup files and append the current timestamp to zip filename
cd "${SERVER_BACKUP_DIR}"
DST_FILE="data-`date +%m-%d-%Y.%H.%M.%S`.zip"
zip -r ${DST_FILE} *

echo "Creating directory ${DIRECTORY_NAME} under bucket ${BUCKET_NAME}"
aws s3api put-object --bucket "${BUCKET_NAME}" --key "${DIRECTORY_NAME}"/

echo "Uploading ${SERVER_BACKUP_DIR}/${DST_FILE} to ${TARGET_URL}"
aws s3 cp "${SERVER_BACKUP_DIR}/${DST_FILE}" "${TARGET_URL}/"

# Print the filename of the uploaded file to s3
echo "${DST_FILE}"

# Cleanup
rm -rf "${SERVER_BACKUP_DIR}"