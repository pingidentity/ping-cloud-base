#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

beluga_log "exporting config settings"
export_config_settings

export encryptionOption=$(getEncryptionOption)
export jvmOptions=$(getJvmOptions)

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

# Enable replication offline.
# "${HOOKS_DIR}"/185-offline-enable-wrapper.sh

# Replicated base DNs must exist before starting the server now that
# replication is enabled before start since otherwise a generation ID of -1
# would be generated, which breaks replication.
add_base_entry_if_needed

run_hook "15-encryption-settings.sh"

beluga_log "run-setup: configuring ${USER_BACKEND_ID} for base DN ${USER_BASE_DN}"
dsconfig --no-prompt --offline set-backend-prop \
  --backend-name "${USER_BACKEND_ID}" \
  --add "base-dn:${USER_BASE_DN}" \
  --set enabled:true \
  --set db-cache-percent:35
CONFIG_STATUS=${?}

beluga_log "run-setup: configure base DN ${USER_BASE_DN} update status: ${CONFIG_STATUS}"
test "${CONFIG_STATUS}" -ne 0 && exit ${CONFIG_STATUS}

beluga_log "run-setup: server install complete"
exit 0