#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"
test -f "${HOOKS_DIR}/pingdirectory.lib.sh" && . "${HOOKS_DIR}/pingdirectory.lib.sh"

########################################################################################################################
# Change the password of the provided user.
#
# Arguments
#   ${1} -> The DN of the user.
#   ${2} -> The file containing the new password file in clear text.
#   ${3} -> Any optional control to be used with the LDAP modify request.
########################################################################################################################
change_user_password() {
  USER_DN="${1}"
  NEW_PASSWORD_FILE="${2}"
  CONTROL="${3}"

  beluga_log "resetting password for user DN: ${USER_DN}"
  if test -z "${CONTROL}"; then
    ldappasswordmodify \
      --authzID "dn:${USER_DN}" \
      --newPasswordFile "${NEW_PASSWORD_FILE}"
  else
    ldappasswordmodify \
      --authzID "dn:${USER_DN}" \
      --newPasswordFile "${NEW_PASSWORD_FILE}" \
      --control "${CONTROL}"
  fi

  pwdModStatus=$?
  beluga_log "password reset for DN ${USER_DN} status: ${pwdModStatus}"

  # The following exit codes are acceptable:
  # 0 -> success
  # 32 -> user does not exist
  # 53 -> old and new passwords are the same
  if test ${pwdModStatus} -ne 0 && test ${pwdModStatus} -ne 32 && test ${pwdModStatus} -ne 53; then
    return ${pwdModStatus}
  fi

  return 0
}

########################################################################################################################
# Change the passwords of the PF administrator user and the internal user that PF uses to communicate with PD.
########################################################################################################################
change_pf_user_passwords() {
  PASS_FILE=$(mktemp)

  echo "${PF_ADMIN_USER_PASSWORD}" > "${PASS_FILE}"
  change_user_password 'uid=administrator,ou=admins,o=platformconfig' "${PASS_FILE}"
  pwdModStatus=$?
  test ${pwdModStatus} -ne 0 && return ${pwdModStatus}

  echo "${PF_LDAP_PASSWORD}" > "${PASS_FILE}"
  change_user_password 'uid=pingfederate,ou=devopsaccount,o=platformconfig' "${PASS_FILE}"
  pwdModStatus=$?
  test ${pwdModStatus} -ne 0 && return ${pwdModStatus}

  return 0
}

########################################################################################################################
# Initialize replication for the provided base DN on this server.
#
# Arguments
#   ${1} -> The base DN for which to initialize replication.
########################################################################################################################
initialize_replication_for_dn() {
  BASE_DN=${1}

  # If multi-cluster, initialize the first server in the secondary cluster from the first server in the primary cluster.
  # Initialize other servers in the secondary cluster from the first server within the same cluster.
  is_multi_cluster && test "${ORDINAL}" -eq 0 &&
    FROM_HOST="${K8S_STATEFUL_SET_NAME}-0.${PD_CLUSTER_PUBLIC_HOSTNAME}" ||
    FROM_HOST="${K8S_STATEFUL_SET_NAME}-0.${DOMAIN_NAME}"
  FROM_PORT="${PD_LDAPS_PORT}"

  TO_HOST="${K8S_STATEFUL_SET_NAME}-${ORDINAL}.${DOMAIN_NAME}"
  TO_PORT="${PD_LDAPS_PORT}"

  beluga_log "running dsreplication initialize for ${BASE_DN} from ${FROM_HOST}:${FROM_PORT} to ${TO_HOST}:${TO_PORT}"
  dsreplication initialize \
    --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
    --trustAll \
    --hostSource "${FROM_HOST}" --portSource "${FROM_PORT}" --useSSLSource \
    --hostDestination "${TO_HOST}" --portDestination "${TO_PORT}" --useSSLDestination \
    --baseDN "${BASE_DN}" \
    --adminUID "${ADMIN_USER_NAME}" \
    --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
    --no-prompt --ignoreWarnings \
    --enableDebug \
    --globalDebugLevel verbose
  replInitResult=$?
  beluga_log "replication initialize for ${BASE_DN} status: ${replInitResult}"

  if test ${replInitResult} -ne 0; then
    beluga_log "contents of dsreplication.log:"
    cat "${SERVER_ROOT_DIR}"/logs/tools/dsreplication.log
  fi

  return ${replInitResult}
}

########################################################################################################################
# Stop the container to signal failure with the post-start sequence.
########################################################################################################################
stop_container() {
  beluga_log "stopping the container to signal failure with post-start sequence"
  stop-server
}


# --- MAIN SCRIPT ---
beluga_log "starting post-start hook"

# TODO: remove after debugging offline-enable
exit 0

beluga_log "running ldapsearch test on this container (${HOSTNAME})"
waitUntilLdapUp localhost "${LDAPS_PORT}" 'cn=config'

beluga_log "exporting config settings"
export_config_settings

beluga_log "pod ordinal: ${ORDINAL}; multi-cluster: ${IS_MULTI_CLUSTER}"

# Change PF user passwords
change_pf_user_passwords
test $? -ne 0 && stop_container

# The request control allows encoded passwords, which is always required for topology admin users
# ldapmodify allows a --passwordUpdateBehavior allow-pre-encoded-password=true to do the same
ALLOW_PRE_ENCODED_PW_CONTROL='1.3.6.1.4.1.30221.2.5.51:true::MAOBAf8='
change_user_password "cn=${ADMIN_USER_NAME}" "${ADMIN_USER_PASSWORD_FILE}" "${ALLOW_PRE_ENCODED_PW_CONTROL}"
test $? -ne 0 && stop_container

# TODO: test if replace-profile can handle this.
# Update the license file, if necessary
LICENSE_FILE_PATH="${LICENSE_DIR}/${LICENSE_FILE_NAME}"

if test -f "${LICENSE_FILE_PATH}"; then
  beluga_log "updating product license from file ${LICENSE_FILE_PATH}"
  dsconfig --no-prompt set-license-prop --set "directory-platform-license-key<${LICENSE_FILE_PATH}"

  licModStatus=$?
  beluga_log "product license update status: ${pwdModStatus}"
  test ${licModStatus} -ne 0 && stop_container
fi

if test "${ORDINAL}" -eq 0 && is_primary_cluster; then
  beluga_log "post-start complete"
  exit
fi

# --- NOTE ---
# This assumes that data initialization is only required once for the initial data in the server profile.
# Subsequent initialization of data will be performed externally after populating one of the servers using data
# sync or some other mechanism, like ldapmodidy, followed by dsreplication initialize-all. This assumption may be
# different for each customer, but the script may be easily adjusted as appropriate for the customer's use case.

REPL_INIT_MARKER_FILE="${SERVER_ROOT_DIR}"/config/repl-initialized

# Figure out if replication is already initialized for all requested DNs
DN_LIST=
if test -z "${REPLICATION_BASE_DNS}"; then
  DN_LIST="${USER_BASE_DN}"
else
  echo "${REPLICATION_BASE_DNS}" | grep -q "${USER_BASE_DN}"
  test $? -eq 0 &&
      DN_LIST="${REPLICATION_BASE_DNS}" ||
      DN_LIST="${REPLICATION_BASE_DNS};${USER_BASE_DN}"
fi

DNS_TO_INITIALIZE=$(echo "${DN_LIST}" | tr ';' ' ')
beluga_log "replication base DNs: ${DNS_TO_INITIALIZE}"

UNINITIALIZED_DNS=
for DN in ${DNS_TO_INITIALIZE}; do
  if grep -q "${DN}" "${REPL_INIT_MARKER_FILE}" &> /dev/null; then
    beluga_log "replication is already initialized for ${DN}"
  else
    test -z "${UNINITIALIZED_DNS}" &&
        UNINITIALIZED_DNS="${DN}" ||
        UNINITIALIZED_DNS="${UNINITIALIZED_DNS} ${DN}"
  fi
done

# All base DNs are already initialized, so we're good.
if test -z "${UNINITIALIZED_DNS}"; then
  beluga_log "replication is already initialized for all base DNs: ${DNS_TO_INITIALIZE}"
  beluga_log "post-start complete"
  exit
fi

beluga_log "replication will be initialized for base DNs: ${UNINITIALIZED_DNS}"

for DN in ${UNINITIALIZED_DNS}; do
  initialize_replication_for_dn "${DN}"
  replInitResult=$?

  if test ${replInitResult} -eq 0; then
    beluga_log "adding DN ${DN} to the replication marker file ${REPL_INIT_MARKER_FILE}"
    echo "${DN}" >> "${REPL_INIT_MARKER_FILE}"
  else
    stop_container
  fi
done

beluga_log "post-start complete"