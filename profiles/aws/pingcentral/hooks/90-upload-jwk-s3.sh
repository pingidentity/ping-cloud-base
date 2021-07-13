#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

cleanUp() {
  # Cleanup upload dir
  rm -rf "${UPLOAD_DIR}"
}

# This guarantees that cleanUp will always run, even if this script exits due to an error
trap "cleanUp" EXIT

JWK_FILE_NAME="pingcentral.jwk"
JWK_FILE="${SERVER_ROOT_DIR}/conf/${JWK_FILE_NAME}"
UPLOAD_DIR="$(mktemp -d)"

if ! test -f "${JWK_FILE}"; then
  beluga_log "Skipping ${JWK_FILE} needs to be available"
  exit 1
fi

beluga_log "Uploading to location ${CHUB_BACKUP_URL}"

# Set required environment variables for skbn
initializeSkbnConfiguration

cp "${JWK_FILE}" "${UPLOAD_DIR}/${JWK_FILE_NAME}"

beluga_log "Copying files in '${UPLOAD_DIR}' to '${SKBN_CLOUD_PREFIX}'"

if ! skbnCopy "${UPLOAD_DIR}" "${SKBN_CLOUD_PREFIX}"; then
  beluga_log "Failed to upload files in ${UPLOAD_DIR}"
  exit 1
fi

beluga_log "Successfully uploaded ${JWK_FILE_NAME} file"

# STDOUT all the files in one line for integration test
ls "${UPLOAD_DIR}" | xargs

exit 0