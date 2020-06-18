#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"

# Allow overriding the backup URL with an arg
test ! -z "${1}" && BACKUP_URL="${1}"
echo "Downloading from location ${BACKUP_URL}"

# Set required environment variables for skbn
initializeSkbnConfiguration

DATA_BACKUP_FILE_NAME=$( echo "${BACKUP_FILE_NAME}" | tr -d '"' )
if ! test -z "${DATA_BACKUP_FILE_NAME}" && \
   ! test "${DATA_BACKUP_FILE_NAME}" = 'null'; then

  echo "Attempting to restore backup from cloud storage specified by the user: ${DATA_BACKUP_FILE_NAME}"
else
  echo "Attempting to restore backup from latest backup file in cloud storage."
  DATA_BACKUP_FILE_NAME="latest.zip"
fi

DOWNLOAD_DIR="${OUT_DIR}/instance/server/default/data/drop-in-deployer"

# Rename backup filename when copying onto pingfederate admin
DST_FILE="data.zip"

echo "Copying: '${DATA_BACKUP_FILE_NAME}' to '${SKBN_K8S_PREFIX}${DOWNLOAD_DIR}'"

if ! skbnCopy "${SKBN_CLOUD_PREFIX}/${DATA_BACKUP_FILE_NAME}" "${SKBN_K8S_PREFIX}${DOWNLOAD_DIR}/${DST_FILE}"; then
  exit 1
fi

unzip -o "${DOWNLOAD_DIR}/${DST_FILE}" \
    pf.jwk \
    -d "${OUT_DIR}/instance/server/default/data"

# Print the filename of the downloaded file from cloud storage.
echo "Download file name: ${DATA_BACKUP_FILE}"

# Print listed files from drop-in-deployer
ls ${DOWNLOAD_DIR}