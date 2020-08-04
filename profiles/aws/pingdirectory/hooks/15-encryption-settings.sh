#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

beluga_log "encryption-settings: starting processing of encryption-settings definitions"

# NOTE: this is a band-aid fix until we have a Docker image with the fix for DS-41478.
# It should be removed as soon as we take an image that has PingDirectory 8.1.0.0.

# Create an encryption-settings definition for every password in the old passwords file
ENCRYPTION_PASSWORD_FILE="${SECRETS_DIR}"/old-encryption-passwords
ENCRYPTION_PASSWORDS=$(cat "${ENCRYPTION_PASSWORD_FILE}" | tr ';' ' ')

for PASS in ${ENCRYPTION_PASSWORDS}; do
  PASS_FILE=$(mktemp)
  echo "${PASS}" > "${PASS_FILE}"

  # Tolerate failures if the encryption-settings already exists.
  beluga_log "encryption-settings: creating a new encryption definition"
  OUTPUT=$(encryption-settings create \
      --cipher-algorithm AES \
      --key-length-bits 128 \
      --passphrase-file "${PASS_FILE}" 2>&1)
  beluga_log "encryption-settings: ${OUTPUT}"
done

beluga_log "encryption-settings: finished processing all encryption-settings definitions"