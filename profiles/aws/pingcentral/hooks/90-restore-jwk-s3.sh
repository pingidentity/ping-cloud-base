#!/usr/bin/env sh

. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

cleanUp() {
  # Cleanup upload dir
  rm -rf "${SERVER_RESTORE_DIR}"
}

JWK_FILE_NAME="pingcentral.jwk"
MASTER_KEY_PATH="${SERVER_ROOT_DIR}/conf/${JWK_FILE_NAME}"

# This is the backup directory on the server
SERVER_RESTORE_DIR="${OUT_DIR}/restore"
cleanUp
mkdir -p "${SERVER_RESTORE_DIR}"

# This guarantees that cleanUp will always run, even if this script exits due to an error
trap "cleanUp" EXIT

# Set required environment variables for skbn
initializeSkbnConfiguration

beluga_log "Copying: '${JWK_FILE_NAME}' to '${SERVER_RESTORE_DIR}/${JWK_FILE_NAME}'"

if ! skbnCopy "${SKBN_CLOUD_PREFIX}/${JWK_FILE_NAME}" "${SERVER_RESTORE_DIR}/${JWK_FILE_NAME}"; then
  beluga_log "Cannot locate s3 bucket ${SKBN_CLOUD_PREFIX}/${JWK_FILE_NAME}"
  exit 1
fi

cp "${SERVER_RESTORE_DIR}/${JWK_FILE_NAME}" "${MASTER_KEY_PATH}"

beluga_log "Successfully restored ${JWK_FILE_NAME} file"

exit 0