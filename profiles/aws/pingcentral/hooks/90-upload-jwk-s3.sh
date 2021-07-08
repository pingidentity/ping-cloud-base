#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

JWK_FILE="${SERVER_ROOT_DIR}/conf/pingcentral.jwk"

if ! test -f "${JWK_FILE}"; then
  beluga_log "Skipping JWK_FILE needs to be available"
  exit 0
fi

beluga_log "Uploading to location ${CHUB_BACKUP_URL}"

# Set required environment variables for skbn
initializeSkbnConfiguration


beluga_log "Copying files to '${SKBN_CLOUD_PREFIX}'"

if ! skbnCopy "${SKBN_K8S_PREFIX}/${JWK_FILE}" "${SKBN_CLOUD_PREFIX}/"; then
  exit 1
fi

beluga_log "Successfully uploaded pingcentral.jwk file"

exit 0
