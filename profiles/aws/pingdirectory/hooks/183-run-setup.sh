#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

beluga_log "initial launch of container"

export encryptionOption=$(getEncryptionOption)
export jvmOptions=$(getJvmOptions)
export LICENSE_KEY_FILE="${LICENSE_DIR}/${LICENSE_FILE_NAME}"

ORIG_UNBOUNDID_JAVA_ARGS="${UNBOUNDID_JAVA_ARGS}"
HEAP_SIZE_INT=$(echo "${MAX_HEAP_SIZE}" | grep 'g$' | cut -d'g' -f1)

if test ! -z "${HEAP_SIZE_INT}" && test "${HEAP_SIZE_INT}" -ge 4; then
  NEW_HEAP_SIZE=$((HEAP_SIZE_INT - 2))g
  beluga_log "run-setup: changing manage-profile heap size to ${NEW_HEAP_SIZE}"
  export UNBOUNDID_JAVA_ARGS="-client -Xmx${NEW_HEAP_SIZE} -Xms${NEW_HEAP_SIZE}"
fi

test -f "${SECRETS_DIR}"/encryption-settings.pin &&
  ENCRYPTION_PIN_FILE="${SECRETS_DIR}"/encryption-settings.pin ||
  ENCRYPTION_PIN_FILE="${SECRETS_DIR}"/encryption-password

beluga_log "Using ${ENCRYPTION_PIN_FILE} as the encryption-setting.pin file"
cp "${ENCRYPTION_PIN_FILE}" "${SERVER_ROOT_DIR}"/config

"${SERVER_ROOT_DIR}"/bin/manage-profile setup \
    --profile "${PD_PROFILE}" \
    --useEnvironmentVariables \
    --tempProfileDirectory /tmp \
    --doNotStart \
    --rejectFile /tmp/rejects.ldif

MANAGE_PROFILE_STATUS=${?}
beluga_log "run-setup: manage-profile setup status: ${MANAGE_PROFILE_STATUS}"

export UNBOUNDID_JAVA_ARGS="${ORIG_UNBOUNDID_JAVA_ARGS}"

if test "${MANAGE_PROFILE_STATUS}" -ne 0; then
  beluga_log "run-setup: contents of manage-profile.log file:"
  cat "${SERVER_ROOT_DIR}/logs/tools/manage-profile.log"

  test -f /tmp/rejects.ldif && cat /tmp/rejects.ldif

  beluga_log "run-setup: server install failed"
  exit 183
fi

# Rebuild indexes, if necessary for the USER_BASE_DN.
beluga_log "Rebuilding any new or untrusted indexes for base DN ${USER_BASE_DN}"
rebuild-index --bulkRebuild new --bulkRebuild untrusted --baseDN "${USER_BASE_DN}"

beluga_log "updating encryption settings"
run_hook "15-encryption-settings.sh"

beluga_log "enabling the replication sub-system in offline mode"
offline_enable_replication
enable_replication_status=$?
if test ${enable_replication_status} -ne 0; then
  beluga_log "replication enable failed with status: ${enable_replication_status}"
  exit ${enable_replication_status}
fi

beluga_log "server install complete"
exit 0