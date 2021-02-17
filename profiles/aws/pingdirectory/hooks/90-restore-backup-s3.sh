#!/bin/sh

. "${HOOKS_DIR}/utils.lib.sh"

# Set required environment variables for skbn
initializeSkbnConfiguration

# This is the backup directory on the server
SERVER_RESTORE_DIR="${OUT_DIR}/restore"

LDAPS_PORT=1636
ROOT_USER_DN=cn=administrator

rm -rf "${SERVER_RESTORE_DIR}"

if ! mkdir -p "${SERVER_RESTORE_DIR}"; then
  beluga_log "Failed to create dir: ${SERVER_RESTORE_DIR}"
  exit 1
fi

DATA_BACKUP_FILE_NAME=$( echo "${BACKUP_FILE_NAME}" | tr -d '"' )
if ! test -z "${DATA_BACKUP_FILE_NAME}" && \
   ! test "${DATA_BACKUP_FILE_NAME}" = 'null'; then

  beluga_log "Attempting to restore backup from cloud storage specified by the user: ${DATA_BACKUP_FILE_NAME}"
else
  beluga_log "Attempting to restore backup from latest backup file in cloud storage."
  DATA_BACKUP_FILE_NAME="latest.zip"
fi

beluga_log "Copying: '${DATA_BACKUP_FILE_NAME}' to '${SKBN_K8S_PREFIX}${SERVER_RESTORE_DIR}/${DATA_BACKUP_FILE_NAME}'"

if ! skbnCopy "${SKBN_CLOUD_PREFIX}/${DATA_BACKUP_FILE_NAME}" "${SKBN_K8S_PREFIX}${SERVER_RESTORE_DIR}/${DATA_BACKUP_FILE_NAME}"; then
  beluga_log "Cannot locate s3 bucket ${SKBN_CLOUD_PREFIX}/${DATA_BACKUP_FILE_NAME}"
  exit 1
fi

if ! cd ${SERVER_RESTORE_DIR}; then
  beluga_log "Failed to chdir to ${SERVER_RESTORE_DIR}"
  exit 1
fi

# Unzip archive user data
if ! unzip -o "${DATA_BACKUP_FILE_NAME}"; then
  beluga_log "Failed to unzip ${DATA_BACKUP_FILE_NAME}"
  exit 1
fi

# Remove zip
if ! rm -rf "${DATA_BACKUP_FILE_NAME}"; then
  beluga_log "Failed to cleanup ${DATA_BACKUP_FILE_NAME}"
  exit 1
fi

# Print listed files from user data archive
if ! ls ${SERVER_RESTORE_DIR}; then
  beluga_log "Failed to list ${SERVER_RESTORE_DIR}"
  exit 1
fi

if test -f "${SERVER_ROOT_DIR}/changelogDb"; then
  beluga_log "Removing changelogDb before restoring user data"

  if ! rm -rf "${SERVER_ROOT_DIR}/changelogDb"; then
    beluga_log "Failed to remove ${SERVER_RESTORE_DIR}/changelogDb"
    exit 1
  fi
fi

beluga_log "Restoring to the latest backups under ${SERVER_RESTORE_DIR}"
BACKEND_DIRS=$(find "${SERVER_RESTORE_DIR}" -name backup.info -exec dirname {} \;)

# If encryption-settings backend is present in the backups, it must be restored first.
# So re-order the backups such that it appears first in the list.
ORDERED_BACKEND_DIRS=
ENCRYPTION_DB_BACKEND_DIR=

for BACKEND_DIR in ${BACKEND_DIRS}; do
  if test "${BACKEND_DIR%encryption-settings}" != "${BACKEND_DIR}"; then
    beluga_log "Found encryption-settings database backend"
    ENCRYPTION_DB_BACKEND_DIR="${BACKEND_DIR}"
  else
    test -z "${ORDERED_BACKEND_DIRS}" &&
        ORDERED_BACKEND_DIRS="${BACKEND_DIR}" ||
        ORDERED_BACKEND_DIRS="${ORDERED_BACKEND_DIRS} ${BACKEND_DIR}"
  fi
done

test ! -z "${ENCRYPTION_DB_BACKEND_DIR}" &&
    ORDERED_BACKEND_DIRS="${ENCRYPTION_DB_BACKEND_DIR} ${ORDERED_BACKEND_DIRS}"

beluga_log "Restore order of backups: ${ORDERED_BACKEND_DIRS}"

for BACKEND_DIR in ${ORDERED_BACKEND_DIRS}; do
  printf "\n----- Doing a restore from ${BACKEND_DIR} -----\n"
  restore --task \
    --useSSL --trustAll \
    --port ${LDAPS_PORT} \
    --bindDN "${ROOT_USER_DN}" \
    --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --backupDirectory "${BACKEND_DIR}" \
    --ignoreCompatibilityWarnings
done

# Cleanup
rm -rf ${SERVER_RESTORE_DIR}
