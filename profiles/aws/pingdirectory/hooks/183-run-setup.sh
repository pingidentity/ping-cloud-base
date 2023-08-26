#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

beluga_log "initial launch of container"

# Executing as background process so that server setup continues
run_hook "02-health-check.sh" &

export encryptionOption=$(getEncryptionOption)
export jvmOptions=$(getJvmOptions)
export LICENSE_KEY_FILE="${LICENSE_DIR}/${LICENSE_FILE_NAME}"

test -f "${SECRETS_DIR}"/encryption-settings.pin &&
  ENCRYPTION_PIN_FILE="${SECRETS_DIR}"/encryption-settings.pin ||
  ENCRYPTION_PIN_FILE="${SECRETS_DIR}"/encryption-password

beluga_log "Using ${ENCRYPTION_PIN_FILE} as the encryption-setting.pin file"
cp "${ENCRYPTION_PIN_FILE}" "${SERVER_ROOT_DIR}"/config

if ! (test "${ORDINAL}" -eq 0 && is_primary_cluster); then
  # Easily access all global variables of base_dns for PingDirectory
  all_base_dns="${PLATFORM_CONFIG_BASE_DN} \
    ${APP_INTEGRATIONS_BASE_DN} \
    ${USER_BASE_DN}"

  # Iterate over all base DNs
  modify_ldif=$(mktemp)
  for base_dn in ${all_base_dns}; do
    cat > "${modify_ldif}" <<EOF
dn: ${base_dn}
changetype: modify
add: ds-sync-generation-id
ds-sync-generation-id: -1
EOF

    # Use -E flag to provide regex
    # '\s*' matches zero or more whitespace characters between 'dn:' and base_dn
    # e.g. the following will still be found in PD_PROFILE
    # a) dn: dc=example,dc=com
    # b) dn:     dc=example,dc=com
    profile_ldif=$(grep -rlE "dn:\s${base_dn}" "${PD_PROFILE}"/ldif/* | head -1)
    test ! -z "${profile_ldif}" && \
      ldifmodify --doNotWrap --suppressComments \
        --sourceLDIF ${profile_ldif} --changesLDIF ${modify_ldif} --targetLDIF ${profile_ldif}

    beluga_log "testing 123"
    cat "${profile_ldif}"
  done
fi

"${SERVER_ROOT_DIR}"/bin/manage-profile setup \
    --profile "${PD_PROFILE}" \
    --useEnvironmentVariables \
    --tempProfileDirectory "${OUT_DIR}" \
    --doNotStart \
    --rejectFile /tmp/rejects.ldif

MANAGE_PROFILE_STATUS=${?}
beluga_log "run-setup: manage-profile setup status: ${MANAGE_PROFILE_STATUS}"

if test "${MANAGE_PROFILE_STATUS}" -ne 0; then
  beluga_log "run-setup: contents of manage-profile.log file:"
  cat "${SERVER_ROOT_DIR}/logs/tools/manage-profile.log"

  test -f /tmp/rejects.ldif && cat /tmp/rejects.ldif

  beluga_error "run-setup: server install failed"
  exit 183
fi

beluga_log "Copy beluga profile files after setup"
run_hook "07-apply-server-profile.sh"

if ! (test "${ORDINAL}" -eq 0 && is_primary_cluster); then
  get_base_entry_ldif_generation_id
  add_base_entry_status=$?
else
  add_base_entry_if_needed
  add_base_entry_status=$?
fi

beluga_log "add base DN ${USER_BASE_DN} status: ${add_base_entry_status}"
if test ${add_base_entry_status} -ne 0; then
  beluga_error "Adding base dn, ${USER_BASE_DN}, failed with status: ${add_base_entry_status}"
  exit ${add_base_entry_status}
fi

if ! "${SKIP_INDEX_BUILD}"; then
  # Rebuild indexes, if necessary for all base DNs.
  rebuild_base_dn_indexes
  rebuild_base_dn_indexes_status=$?
  if test ${rebuild_base_dn_indexes_status} -ne 0; then
    beluga_error "Rebuilding base DN indexes failed with status: ${rebuild_base_dn_indexes_status}"
    exit ${rebuild_base_dn_indexes_status}
  fi
else
  beluga_warn "Opting to skip building indexes. This requires a manual build of the indexes later."
fi

beluga_log "updating encryption settings"
run_hook "15-encryption-settings.sh"

beluga_log "enabling the replication sub-system in offline mode"
offline_enable_replication
enable_replication_status=$?
if test ${enable_replication_status} -ne 0; then
  beluga_error "replication enable failed with status: ${enable_replication_status}"
  exit ${enable_replication_status}
fi

beluga_log "server install complete"
exit 0