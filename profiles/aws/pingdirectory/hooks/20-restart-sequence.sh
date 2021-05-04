#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

beluga_log "restarting container"

# Remove the post-start initialization marker file so the pod isn't prematurely considered ready
rm -f "${POST_START_INIT_MARKER_FILE}"

# Before running any ds tools, remove java.properties and re-create it
# for the current JVM.
beluga_log "Re-generating java.properties for current JVM"
rm -f "${SERVER_ROOT_DIR}/config/java.properties"
dsjavaproperties --initialize --jvmTuningParameter AGGRESSIVE --maxHeapSize ${MAX_HEAP_SIZE}

# If this hook is provided it can be executed early on
beluga_log "restart-sequence: updating server profile"
run_hook "21-update-server-profile.sh"

export encryptionOption=$(getEncryptionOption)
export jvmOptions=$(getJvmOptions)

EXTERNAL_LICENSE_FILE_NAME="${IN_DIR}/instance/${LICENSE_FILE_NAME}"
test -f "${EXTERNAL_LICENSE_FILE_NAME}" &&
  export LICENSE_KEY_FILE="${EXTERNAL_LICENSE_FILE_NAME}" ||
  export LICENSE_KEY_FILE="${LICENSE_DIR}/${LICENSE_FILE_NAME}"

# Copy the license file into the PD profiles directory. Otherwise, replace-profile cannot detect if it has changed.
beluga_log "Copying the license key into the PD profiles directory"
PD_PROFILE_LICENSE_FILE="${STAGING_DIR}/pd.profile/server-root/pre-setup/${LICENSE_FILE_NAME}"
cp -af "${LICENSE_KEY_FILE}" "${PD_PROFILE_LICENSE_FILE}"

ORIG_UNBOUNDID_JAVA_ARGS="${UNBOUNDID_JAVA_ARGS}"
HEAP_SIZE_INT=$(echo "${MAX_HEAP_SIZE}" | grep 'g$' | cut -d'g' -f1)

if test ! -z "${HEAP_SIZE_INT}" && test "${HEAP_SIZE_INT}" -ge 4; then
  NEW_HEAP_SIZE=$((HEAP_SIZE_INT - 2))g
  beluga_log "changing manage-profile heap size to ${NEW_HEAP_SIZE}"
  export UNBOUNDID_JAVA_ARGS="-client -Xmx${NEW_HEAP_SIZE} -Xms${NEW_HEAP_SIZE}"
fi

test -f "${SECRETS_DIR}"/encryption-settings.pin &&
  ENCRYPTION_PIN_FILE="${SECRETS_DIR}"/encryption-settings.pin ||
  ENCRYPTION_PIN_FILE="${SECRETS_DIR}"/encryption-password

beluga_log "Using ${ENCRYPTION_PIN_FILE} as the encryption-setting.pin file"
cp "${ENCRYPTION_PIN_FILE}" "${PD_PROFILE}"/server-root/pre-setup/config

beluga_log "Merging changes from new server profile"

ADDITIONAL_ARGS="--replaceFullProfile"
if "${OPTIMIZE_REPLACE_PROFILE}"; then
  beluga_log "Running replace-profile in optimized mode"
  ADDITIONAL_ARGS=
fi

"${SERVER_BITS_DIR}"/bin/manage-profile replace-profile \
    --serverRoot "${SERVER_ROOT_DIR}" \
    --profile "${PD_PROFILE}" \
    --useEnvironmentVariables \
    ${ADDITIONAL_ARGS} \
    --reimportData never

MANAGE_PROFILE_STATUS=${?}
beluga_log "manage-profile replace-profile status: ${MANAGE_PROFILE_STATUS}"

export UNBOUNDID_JAVA_ARGS="${ORIG_UNBOUNDID_JAVA_ARGS}"

if test "${MANAGE_PROFILE_STATUS}" -ne 0; then
  beluga_log "Contents of manage-profile.log file:"
  cat "${SERVER_BITS_DIR}/logs/tools/manage-profile.log"
  exit 20
fi

# Rebuild indexes, if necessary for the USER_BASE_DN.
beluga_log "Rebuilding any new or untrusted indexes for base DN ${USER_BASE_DN}"
rebuild-index --bulkRebuild new --bulkRebuild untrusted --baseDN "${USER_BASE_DN}"

beluga_log "updating tools.properties"
run_hook "185-apply-tools-properties.sh"

beluga_log "updating encryption settings"
run_hook "15-encryption-settings.sh"

beluga_log "enabling the replication sub-system in offline mode"
offline_enable_replication
enable_replication_status=$?
if test ${enable_replication_status} -ne 0; then
  beluga_log "replication enable failed with status: ${enable_replication_status}"
  exit ${enable_replication_status}
fi

beluga_log "restart sequence done"
exit 0