#!/bin/sh
set -e

. "${HOOKS_DIR}/utils.lib.sh"


# Source generated environment variables 
test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"

# Set required environment variables for skbn
initializeSkbnConfiguration

# This is the backup directory on the server
SERVER_BACKUP_DIR="${OUT_DIR}/backup"

rm -rf "${SERVER_BACKUP_DIR}"
mkdir -p "${SERVER_BACKUP_DIR}"

BACKENDS=$(echo "${BACKENDS_TO_BACKUP}" | tr ';' ' ')
echo "Doing a full backup of backends \"${BACKENDS}\" to ${SERVER_BACKUP_DIR}"

for BACKEND_ID in ${BACKENDS}; do
  BACKEND_BACKUP_DIR="${SERVER_BACKUP_DIR}/${BACKEND_ID}"
  printf "\n----- Doing a full backup of ${BACKEND_ID} backend to ${BACKEND_BACKUP_DIR} -----\n"
  backup --task \
    --useSSL --trustAll \
    --port ${LDAPS_PORT} \
    --bindDN "${ROOT_USER_DN}" \
    --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --backupDirectory "${BACKEND_BACKUP_DIR}" \
    --backendID "${BACKEND_ID}" \
    --compress
done

# Zip backup files and append the current timestamp to zip filename
cd "${SERVER_BACKUP_DIR}"
DST_FILE_TIMESTAMP="data-$(date +%m-%d-%Y.%H.%M.%S).zip"
zip -r "${DST_FILE_TIMESTAMP}" *

# Two copy of the backup will be pushed to cloud storage.
# Make a copy: latest.zip
DST_FILE_LATEST=latest.zip
cp "$DST_FILE_TIMESTAMP" "$DST_FILE_LATEST" 

echo "Uploading ${DST_FILE_LATEST} to ${SKBN_CLOUD_PREFIX}/${DST_FILE_LATEST}"
if ! skbn cp \
  --src "${SKBN_K8S_PREFIX}/${SERVER_BACKUP_DIR}/${DST_FILE_LATEST}" \
  --dst "${SKBN_CLOUD_PREFIX}/${DST_FILE_LATEST}"; then
  
  echo "skbn failed to upload ${DST_FILE_LATEST} to ${SKBN_CLOUD_PREFIX}"
  exit 1
fi 

# Print the filename of the uploaded file to cloud storage.
echo "${DST_FILE_LATEST}"

echo "Uploading ${DST_FILE_TIMESTAMP} to ${SKBN_CLOUD_PREFIX}/${DST_FILE_TIMESTAMP}"
if ! skbn cp \
  --src "${SKBN_K8S_PREFIX}/${SERVER_BACKUP_DIR}/${DST_FILE_TIMESTAMP}" \
  --dst "${SKBN_CLOUD_PREFIX}/${DST_FILE_TIMESTAMP}"; then

  echo "skbn failed to upload ${DST_FILE_TIMESTAMP} to ${SKBN_CLOUD_PREFIX}"
  exit 1
fi 

# Print the filename of the uploaded file to cloud storage.
echo "${DST_FILE_TIMESTAMP}"

# Cleanup
rm -rf "${SERVER_BACKUP_DIR}"