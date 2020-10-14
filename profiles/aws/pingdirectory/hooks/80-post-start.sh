#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

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
# Perform finalization on exit.
# - On non-zero exit, stop the container to signal failure with the post-start sequence.
# - On success:
#   - Add the marker file signaling that post-start is complete
#   - Start tailing all log files
########################################################################################################################
finalize() {
  if test $? -ne 0; then
    beluga_log "stopping the container to signal failure with post-start sequence"
    stop-server
  fi

  touch "${POST_START_INIT_MARKER_FILE}"
  beluga_log "post-start complete"

  run_hook "100-tail-logs.sh"
}


# --- MAIN SCRIPT ---
beluga_log "starting post-start hook"

# Trap all exit codes from here on so finalization is run
trap "finalize" EXIT

# Remove the post-start initialization marker file so the pod isn't prematurely considered ready
rm -f "${POST_START_INIT_MARKER_FILE}"

beluga_log "running ldapsearch test on this container (${HOSTNAME})"
waitUntilLdapUp localhost "${LDAPS_PORT}" 'cn=config'

beluga_log "pod ordinal: ${ORDINAL}; multi-cluster: ${IS_MULTI_CLUSTER}"

# Change PF user passwords
change_pf_user_passwords
test $? -ne 0 && exit 1

# The request control allows encoded passwords, which is always required for topology admin users
# ldapmodify allows a --passwordUpdateBehavior allow-pre-encoded-password=true to do the same
ALLOW_PRE_ENCODED_PW_CONTROL='1.3.6.1.4.1.30221.2.5.51:true::MAOBAf8='
change_user_password "cn=${ADMIN_USER_NAME}" "${ADMIN_USER_PASSWORD_FILE}" "${ALLOW_PRE_ENCODED_PW_CONTROL}"
test $? -ne 0 && exit 1

# --- NOTE ---
# This assumes that data initialization is only required once for the initial data in the server profile.
# Subsequent initialization of data will be performed externally after populating one of the servers using data
# sync or some other mechanism, like ldapmodidy, followed by dsreplication initialize-all. This assumption may be
# different for each customer, but the script may be easily adjusted as appropriate for the customer's use case.

# Figure out if replication is already initialized for all requested DNs
# All base DNs are already initialized, so we're good.
if test -z "${UNINITIALIZED_DNS}"; then
  beluga_log "replication is already initialized for all base DNs: ${DNS_TO_ENABLE}"
  exit 0
fi

# If we're told to not initialize data, then skip it
if ! "${INITIALIZE_REPLICATION_DATA}"; then
  beluga_log "not initializing replication data because INITIALIZE_REPLICATION_DATA is false"
  exit 0
fi

if test "${ORDINAL}" -eq 0 && is_primary_cluster; then
  beluga_log "seed server in the primary cluster"

  if test ! -f "${REPL_INIT_MARKER_FILE}"; then
    # As the other servers come up, they'll initialize replication data from another server.
    # So we can skip replication here.
    beluga_log "initial launch - all DNs will be initialized by each server as they come up"
    for DN in ${UNINITIALIZED_DNS}; do
      echo "${DN}" >> "${REPL_INIT_MARKER_FILE}"
    done

    exit 0
  else
    # If the USER_BASE_DN changes (e.g. from dc=example,dc=com to dc=refinitiv,dc=com), then
    # replication data must be initialized to all servers from the primary server. The individual
    # servers cannot initialize themselves because the rollout happens in reverse order, and the
    # user base DN will not exist on the servers that haven't been rolled out yet.
    beluga_log "restart - data will be initialized from seed server to all servers for base DNs: ${UNINITIALIZED_DNS}"
    command_to_run="initialize_all_servers_for_dn"
  fi
else
  beluga_log "non-seed server - will initialize data from another server"
  command_to_run="initialize_server_for_dn"
fi

beluga_log "replication will be initialized for base DNs: ${UNINITIALIZED_DNS}"
for DN in ${UNINITIALIZED_DNS}; do
  ${command_to_run} "${DN}"
  replInitResult=$?

  if test ${replInitResult} -eq 0; then
    beluga_log "adding DN ${DN} to the replication marker file ${REPL_INIT_MARKER_FILE}"
    echo "${DN}" >> "${REPL_INIT_MARKER_FILE}"
  else
    exit 1
  fi
done

exit 0