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

#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

JWK_FILE="${SERVER_ROOT_DIR}/conf/pingcentral.jwk"

if ! test -f "${JWK_FILE}"; then
  beluga_log "Skipping JWK_FILE needs to be available"
  exit 0
fi

beluga_log "Uploading to location ${CHUB_BUCKET_URL}"

# Set required environment variables for skbn
initializeSkbnConfiguration


beluga_log "Copying files to '${SKBN_CLOUD_PREFIX}'"

if ! skbnCopy "${SKBN_K8S_PREFIX}/${JWK_FILE}" "${SKBN_CLOUD_PREFIX}/"; then
  exit 1
fi

beluga_log "Successfully restored pingcentral.jwk file"
exit 0