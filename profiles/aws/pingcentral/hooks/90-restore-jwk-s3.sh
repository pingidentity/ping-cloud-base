#!/usr/bin/env sh

. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

# Set required environment variables for skbn
initializeSkbnConfiguration

JWK_FILE_NAME="pingcentral.jwk"
MASTER_KEY_PATH="${SERVER_ROOT_DIR}/conf/${JWK_FILE_NAME}"

beluga_log "Copying: '${JWK_FILE_NAME}' to '${SKBN_K8S_PREFIX}${MASTER_KEY_PATH}'"


if ! skbnCopy "${SKBN_CLOUD_PREFIX}/${JWK_FILE_NAME}" "${SKBN_K8S_PREFIX}${MASTER_KEY_PATH}"; then
  beluga_log "Cannot locate s3 bucket ${SKBN_CLOUD_PREFIX}/${JWK_FILE_NAME}"
  exit 1
fi

beluga_log "Successfully restored ${JWK_FILE_NAME} file"

exit 0