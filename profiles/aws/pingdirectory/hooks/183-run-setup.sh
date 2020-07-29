#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

export encryptionOption=$(getEncryptionOption)
export jvmOptions=$(getJvmOptions)

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
beluga_log "manage-profile setup status: ${MANAGE_PROFILE_STATUS}"

if test "${MANAGE_PROFILE_STATUS}" -ne 0; then
  beluga_log "Contents of manage-profile.log file:"
  cat "${SERVER_ROOT_DIR}/logs/tools/manage-profile.log"
  test -f /tmp/rejects.ldif && cat /tmp/rejects.ldif
  exit 183
fi

run_hook "15-encryption-settings.sh"

beluga_log "Configuring ${USER_BACKEND_ID} for base DN ${USER_BASE_DN}"
dsconfig --no-prompt --offline set-backend-prop \
  --backend-name "${USER_BACKEND_ID}" \
  --add "base-dn:${USER_BASE_DN}" \
  --set enabled:true \
  --set db-cache-percent:35
CONFIG_STATUS=${?}

beluga_log "Configure base DN ${USER_BASE_DN} update status: ${CONFIG_STATUS}"
test "${CONFIG_STATUS}" -ne 0 && exit ${CONFIG_STATUS}

exit 0