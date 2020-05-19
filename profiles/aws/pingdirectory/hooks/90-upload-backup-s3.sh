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

UPLOAD_DIR="$(mktemp -d)"

# Two copy of the backup will be pushed to cloud storage.
# Make a copy: latest.zip
DST_FILE_LATEST=latest.zip
cp "$DST_FILE_TIMESTAMP" "${UPLOAD_DIR}/${DST_FILE_TIMESTAMP}"
cp "$DST_FILE_TIMESTAMP" "${UPLOAD_DIR}/${DST_FILE_LATEST}"

echo "Copying files in '${UPLOAD_DIR}' to '${SKBN_CLOUD_PREFIX}'"

if ! skbnCopy "${SKBN_K8S_PREFIX}/${UPLOAD_DIR}" "${SKBN_CLOUD_PREFIX}/"; then
  exit 1
fi

# STDOUT for CI test
ls ${UPLOAD_DIR}

# Cleanup
rm -rf "${SERVER_BACKUP_DIR}"
rm -rf "${UPLOAD_DIR}"