#!/bin/sh
set -e

. "${HOOKS_DIR}/utils.lib.sh"

test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"

# Set required environment variables for skbn
initializeSkbnConfiguration

# This is the backup directory on the server
SERVER_RESTORE_DIR="/tmp/restore"

rm -rf "${SERVER_RESTORE_DIR}"

if ! mkdir -p "${SERVER_RESTORE_DIR}"; then 
  echo "Failed to create dir: ${SERVER_RESTORE_DIR}"
  exit 1
fi 

DATA_BACKUP_FILE_NAME=$( echo "${BACKUP_FILE_NAME}" | tr -d '"' )
if ! test -z "${DATA_BACKUP_FILE_NAME}" && \
   ! test "${DATA_BACKUP_FILE_NAME}" = 'null'; then

  echo "Attempting to restore backup from cloud storage specified by the user: ${DATA_BACKUP_FILE_NAME}"
else
  echo "Attempting to restore backup from latest backup file in cloud storage."
  DATA_BACKUP_FILE_NAME="latest.zip"
fi

echo "Copying: '${DATA_BACKUP_FILE_NAME}' to '${SKBN_K8S_PREFIX}${SERVER_RESTORE_DIR}/${DATA_BACKUP_FILE_NAME}'"

if ! skbnCopy "${SKBN_CLOUD_PREFIX}/${DATA_BACKUP_FILE_NAME}" "${SKBN_K8S_PREFIX}${SERVER_RESTORE_DIR}/${DATA_BACKUP_FILE_NAME}"; then
  exit 1
fi

if ! cd ${SERVER_RESTORE_DIR}; then 
  echo "Failed to chdir to ${SERVER_RESTORE_DIR}"
  exit 1
fi 

# Unzip archive user data
if ! unzip -o "${DATA_BACKUP_FILE_NAME}"; then 
  echo "Failed to unzip ${DATA_BACKUP_FILE_NAME}"
  exit 1
fi 

# Remove zip
if ! rm -rf "${DATA_BACKUP_FILE_NAME}"; then 
  echo "Failed to cleanup ${DATA_BACKUP_FILE_NAME}"
  exit 1
fi

# Print listed files from user data archive
if ! ls ${SERVER_RESTORE_DIR}; then
  echo "Failed to list ${SERVER_RESTORE_DIR}"
  exit 1
fi 

if test -f "${SERVER_ROOT_DIR}/changelogDb"; then
  echo "Removing changelogDb before restoring user data"
  
  if ! rm -rf "${SERVER_ROOT_DIR}/changelogDb"; then
    echo "Failed to remove ${SERVER_RESTORE_DIR}/changelogDb"
    exit 1
  fi
fi 

echo "Restoring to the latest backups under ${SERVER_RESTORE_DIR}"
BACKEND_DIRS=$(find "${SERVER_RESTORE_DIR}" -name backup.info -exec dirname {} \;)

for BACKEND_DIR in ${BACKEND_DIRS}; do
  printf "\n----- Doing a restore from ${BACKEND_DIR} -----\n"
  restore --task \
    --useSSL --trustAll \
    --port ${LDAPS_PORT} \
    --bindDN "${ROOT_USER_DN}" \
    --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --backupDirectory "${BACKEND_DIR}"
done

# Cleanup
rm -rf ${SERVER_RESTORE_DIR}