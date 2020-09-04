#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/utils.lib.sh"

# Set PATH - since this is executed from within the server process, it may not have all we need on the path
export PATH="${PATH}:${SERVER_ROOT_DIR}/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${JAVA_HOME}/bin"

# Allow overriding the log archive URL with an arg
test ! -z "${1}" && LOG_ARCHIVE_URL="${1}"
beluga_log "Uploading to location ${LOG_ARCHIVE_URL}"

# Set required environment variables for skbn
initializeSkbnConfiguration "${LOG_ARCHIVE_URL}"

if ! cd "${OUT_DIR}"; then
  beluga_log "Failed to chdir to: ${OUT_DIR}"
  exit 1
fi

# Invoke the collect-support-data script
collect-support-data --duration 1h
CSD_OUT=$(find . -name support\*zip -type f | sort | tail -1)

# collect-support-data in PingDirectory outputs a file with a name like:
#
#   support-data-ds-8.1.0.1-pingdirectory-0-20200903203030Z-zip
#
# For consistency, with the other production csd zip files, strip the
# last 2 digits and the Zulu time indicator with ..Z-zip and replace
# it with the .zip extension:
#
#   support-data-ds-8.1.0.1-pingdirectory-0-202009032030.zip
#
DST_FILE="$(basename "${CSD_OUT}" .zip | sed 's/..Z-zip/.zip/')"
SRC_FILE="${OUT_DIR}/$(basename "${CSD_OUT}")"

beluga_log "Copying: '${DST_FILE}' to '${SKBN_CLOUD_PREFIX}'"

if ! skbnCopy "${SKBN_K8S_PREFIX}/${SRC_FILE}" "${SKBN_CLOUD_PREFIX}/${DST_FILE}"; then
  exit 1
fi

# Remove the CSD file so it is doesn't fill up the server's filesystem.
rm -f "${CSD_OUT}"

# Print the filename so callers can figure out the name of the CSD file that was uploaded.
echo "${DST_FILE}"
