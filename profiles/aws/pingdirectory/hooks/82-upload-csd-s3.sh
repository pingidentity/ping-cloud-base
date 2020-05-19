#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/utils.lib.sh"

test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"

# Set PATH - since this is executed from within the server process, it may not have all we need on the path
export PATH="${PATH}:${SERVER_ROOT_DIR}/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${JAVA_HOME}/bin"

# Allow overriding the log archive URL with an arg
test ! -z "${1}" && LOG_ARCHIVE_URL="${1}"
echo "Uploading to location ${LOG_ARCHIVE_URL}"

if ! cd "${OUT_DIR}"; then
  echo "Failed to chdir to: ${OUT_DIR}"
  exit 1
fi

collect-support-data --duration 1h
CSD_OUT=$(find . -name support\*zip -type f | sort | tail -1)

# Set required environment variables for skbn
initializeSkbnConfiguration "${LOG_ARCHIVE_URL}"

DST_FILE="$(basename "${CSD_OUT}")"
SRC_FILE="${OUT_DIR}/$(basename "${CSD_OUT}")"

echo "Copying: '${DST_FILE}' to '${SKBN_CLOUD_PREFIX}'"

if ! skbnCopy "${SKBN_K8S_PREFIX}/${SRC_FILE}" "${SKBN_CLOUD_PREFIX}/${DST_FILE}"; then
  exit 1
fi

# Remove the CSD file so it is doesn't fill up the server's filesystem.
rm -f "${CSD_OUT}"

# Print the filename so callers can figure out the name of the CSD file that was uploaded.
echo "${DST_FILE}"
