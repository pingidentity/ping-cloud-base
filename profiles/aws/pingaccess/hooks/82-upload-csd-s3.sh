#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"

beluga_log "Uploading to location ${LOG_ARCHIVE_URL}"

# Set required environment variables for skbn
initializeSkbnConfiguration "${LOG_ARCHIVE_URL}"

if ! cd "${OUT_DIR}"; then 
  beluga_log "Failed to chdir: ${OUT_DIR}"
  exit 1
fi

if ! sh ${SERVER_ROOT_DIR}/bin/collect-support-data.sh; then 
  beluga_log "Failed to execute:  ${SERVER_ROOT_DIR}/bin/collect-support-data.sh"
  exit 1
fi

CSD_OUT=$(find . -name support\*zip -type f | sort | tail -1)

# Change CSD file which will be uploaded to S3 for matching <YYYYMMDDHHMM>-support-data-ping-<CONTAINER_NAME>.zip

# Extracting datetime part and converting to <YYYYMMDDHHMM> format
DST_FILE_DATETIME="$(basename "${CSD_OUT}" .zip | grep -o '[^-]*$' | sed 's/..$//')"
# Extracting CSD file prefix
DST_FILE_PREFIX="$(basename "${CSD_OUT}" .zip | sed "s/-${DST_FILE_DATETIME}//")"

DST_FILE="${DST_FILE_DATETIME}-${DST_FILE_PREFIX}.zip"
SRC_FILE="${OUT_DIR}/$(basename "${CSD_OUT}")"

beluga_log "Copying: '${DST_FILE}' to '${SKBN_CLOUD_PREFIX}'"

if ! skbnCopy "${SKBN_K8S_PREFIX}/${SRC_FILE}" "${SKBN_CLOUD_PREFIX}/${DST_FILE}"; then
  exit 1
fi

# Remove the CSD file so it is doesn't fill up the server's filesystem.
rm -f "${CSD_OUT}"

# Print the filename so callers can figure out the name of the CSD file that was uploaded.
echo "${DST_FILE}"