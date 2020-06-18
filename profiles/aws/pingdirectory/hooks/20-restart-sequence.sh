#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

echo "Restarting container"

# Before running any ds tools, remove java.properties and re-create it
# for the current JVM.
echo "Re-generating java.properties for current JVM"
rm -f "${SERVER_ROOT_DIR}/config/java.properties"
dsjavaproperties --initialize --jvmTuningParameter AGGRESSIVE --maxHeapSize ${MAX_HEAP_SIZE}

# If this hook is provided it can be executed early on
run_hook "21-update-server-profile.sh"

export encryptionOption=$(getEncryptionOption)
export jvmOptions=$(getJvmOptions)

echo "Checking license file"
_currentLicense="${LICENSE_DIR}/${LICENSE_FILE_NAME}"
_pdProfileLicense="${STAGING_DIR}/pd.profile/server-root/pre-setup/${LICENSE_FILE_NAME}"

if test ! -f "${_pdProfileLicense}" ; then
  echo "Copying in license from existing install."
  echo "  ${_currentLicense} ==> "
  echo "    ${_pdProfileLicense}"
  cp -af "${_currentLicense}" "${_pdProfileLicense}"
fi

test -f "${SECRETS_DIR}"/encryption-settings.pin &&
  ENCRYPTION_PIN_FILE="${SECRETS_DIR}"/encryption-settings.pin ||
  ENCRYPTION_PIN_FILE="${SECRETS_DIR}"/encryption-password

echo "Using ${ENCRYPTION_PIN_FILE} as the encryption-setting.pin file"
cp "${ENCRYPTION_PIN_FILE}" "${PD_PROFILE}"/server-root/pre-setup/config

# FIXME: Workaround for DS-41964 - use --replaceFullProfile flag to replace-profile
echo "Merging changes from new server profile"

ADDITIONAL_ARGS="--replaceFullProfile"
if "${OPTIMIZE_REPLACE_PROFILE}"; then
  echo "Running replace-profile in optimized mode"
  ADDITIONAL_ARGS=
fi

"${SERVER_BITS_DIR}"/bin/manage-profile replace-profile \
    --serverRoot "${SERVER_ROOT_DIR}" \
    --profile "${PD_PROFILE}" \
    --useEnvironmentVariables \
    ${ADDITIONAL_ARGS} \
    --reimportData never

MANAGE_PROFILE_STATUS=${?}
echo "manage-profile replace-profile status: ${MANAGE_PROFILE_STATUS}"

if test "${MANAGE_PROFILE_STATUS}" -ne 0; then
  echo "Contents of manage-profile.log file:"
  cat "${SERVER_BITS_DIR}/logs/tools/manage-profile.log"
  exit 20
fi

run_hook "185-apply-tools-properties.sh"
run_hook "15-encryption-settings.sh"

# FIXME: replace-profile has a bug where it may wipe out the user root backend configuration and lose user data added
# from another server while enabling replication. This code block may be removed when replace-profile is fixed.
echo "Configuring ${USER_BACKEND_ID} for base DN ${USER_BASE_DN}"
dsconfig --no-prompt --offline set-backend-prop \
  --backend-name "${USER_BACKEND_ID}" \
  --add "base-dn:${USER_BASE_DN}" \
  --set enabled:true \
  --set db-cache-percent:35
CONFIG_STATUS=${?}

echo "Configure base DN ${USER_BASE_DN} update status: ${CONFIG_STATUS}"
test "${CONFIG_STATUS}" -ne 0 && exit ${CONFIG_STATUS}

exit 0