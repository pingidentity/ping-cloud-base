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
# Enable a LDAPS connection handler at the provided port on localhost.
#
# Arguments
#   ${1} -> The port on which to add an LDAPS connection handler on localhost.
########################################################################################################################
enable_ldap_connection_handler() {
  PORT=${1}

  beluga_log "enabling LDAPS connection handler at port ${PORT}"
  dsconfig --no-prompt create-connection-handler \
    --handler-name "External LDAPS Connection Handler ${PORT}" \
    --type ldap \
    --set enabled:true \
    --set listen-port:${PORT} \
    --set use-ssl:true \
    --set ssl-cert-nickname:server-cert \
    --set key-manager-provider:JKS \
    --set trust-manager-provider:JKS
  result=$?
  beluga_log "LDAPS enable at port ${PORT} status: ${result}"

  if test ${result} -eq 68; then
    beluga_log "LDAPS connection handler already exists at port ${PORT}"
    return 0
  fi

  return "${result}"
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
  if is_multi_cluster && test "${ORDINAL}" -eq 0; then
    FROM_HOST="${PD_PRIMARY_PUBLIC_HOSTNAME}"
    FROM_PORT=6360
  else
    FROM_HOST="${K8S_STATEFUL_SET_NAME}-0.${DOMAIN_NAME}"
    FROM_PORT="${LDAPS_PORT}"
  fi

  TO_HOST="${K8S_STATEFUL_SET_NAME}-${ORDINAL}.${DOMAIN_NAME}"
  TO_PORT="${LDAPS_PORT}"

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
# Resets the force-as-master flag to false on the source or seed server if REMOVE_SERVER_FROM_TOPOLOGY_FIRST is true.
# Then, stop the container to signal failure with the post-start sequence.
########################################################################################################################
stop_container() {
  beluga_log "stopping the container to signal failure with post-start sequence"
  stop-server
}


# --- MAIN SCRIPT ---
beluga_log "starting post-start hook"

beluga_log "running ldapsearch test on this container (${HOSTNAME})"
waitUntilLdapUp localhost "${LDAPS_PORT}" 'cn=config'

SHORT_HOST_NAME=$(hostname)
DOMAIN_NAME=$(hostname -f | cut -d'.' -f2-)
ORDINAL=${SHORT_HOST_NAME##*-}

beluga_log "pod ordinal: ${ORDINAL}; multi-cluster: ${IS_MULTI_CLUSTER}"

beluga_log "getting server instance name from global config"
INSTANCE_NAME=$(dsconfig --no-prompt get-global-configuration-prop \
    --property instance-name --script-friendly | awk '{ print $2 }')
beluga_log "server instance name from global config: ${INSTANCE_NAME}"

# Add an LDAPS connection handler for external access, if necessary
if test ! -z "${PD_PUBLIC_HOSTNAME}"; then
  EXTERNAL_LDAPS_PORT="636${ORDINAL}"
  enable_ldap_connection_handler "${EXTERNAL_LDAPS_PORT}"
  test $? -ne 0 && stop_container

  # Change the port, but not the hostname.
  dsconfig --no-prompt set-server-instance-prop \
      --instance-name "${INSTANCE_NAME}" \
      --set ldaps-port:"${EXTERNAL_LDAPS_PORT}"
  result=$?
  beluga_log "change hostname/port: ${result}"
  test $? -ne 0 && stop_container

  dsconfig --no-prompt set-server-instance-listener-prop \
      --instance-name "${INSTANCE_NAME}" \
      --listener-name ldap-listener-mirrored-config \
      --set server-ldap-port:"${EXTERNAL_LDAPS_PORT}"
  result=$?
  beluga_log "change LDAP listener port: ${result}"
  test $? -ne 0 && stop_container
fi

# Change PF user passwords
change_pf_user_passwords
test $? -ne 0 && stop_container

# The request control allows encoded passwords, which is always required for topology admin users
# ldapmodify allows a --passwordUpdateBehavior allow-pre-encoded-password=true to do the same
ALLOW_PRE_ENCODED_PW_CONTROL='1.3.6.1.4.1.30221.2.5.51:true::MAOBAf8='
change_user_password "cn=${ADMIN_USER_NAME}" "${ADMIN_USER_PASSWORD_FILE}" "${ALLOW_PRE_ENCODED_PW_CONTROL}"
test $? -ne 0 && stop_container

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

# Determine the hostnames and ports to use while initializing replication. When in multi-cluster mode and not in the
# primary cluster, use the external names and ports. Otherwise, use internal names and ports.
if is_multi_cluster; then
  REPL_SRC_HOST="${PD_PRIMARY_PUBLIC_HOSTNAME}"
  REPL_SRC_LDAPS_PORT=6360
  REPL_SRC_REPL_PORT=9890
  REPL_DST_HOST="${PD_PUBLIC_HOSTNAME}"
  REPL_DST_LDAPS_PORT="636${ORDINAL}"
  REPL_DST_REPL_PORT="989${ORDINAL}"
else
  REPL_SRC_HOST="${K8S_STATEFUL_SET_NAME}-0.${DOMAIN_NAME}"
  REPL_SRC_LDAPS_PORT="${LDAPS_PORT}"
  REPL_SRC_REPL_PORT=${REPLICATION_PORT}
  REPL_DST_HOST="${K8S_STATEFUL_SET_NAME}-${ORDINAL}.${DOMAIN_NAME}"
  REPL_DST_LDAPS_PORT="${LDAPS_PORT}"
  REPL_DST_REPL_PORT=${REPLICATION_PORT}
fi

SEED_HOST="${REPL_SRC_HOST}"
SEED_PORT="${REPL_SRC_LDAPS_PORT}"

beluga_log "using REPL_SRC_HOST: ${REPL_SRC_HOST}"
beluga_log "using REPL_SRC_LDAPS_PORT: ${REPL_SRC_LDAPS_PORT}"
beluga_log "using REPL_SRC_REPL_PORT: ${REPL_SRC_REPL_PORT}"
beluga_log "using REPL_DST_HOST: ${REPL_DST_HOST}"
beluga_log "using REPL_DST_LDAPS_PORT: ${REPL_DST_LDAPS_PORT}"
beluga_log "using REPL_DST_REPL_PORT: ${REPL_DST_REPL_PORT}"

# If in multi-region mode, wait for the replication source and target servers to be up and running through the
# load balancer before initializing replication.
if is_multi_cluster; then
  beluga_log "waiting for the replication seed server ${REPL_SRC_HOST}:${REPL_SRC_LDAPS_PORT}"
  waitUntilLdapUp "${REPL_SRC_HOST}" "${REPL_SRC_LDAPS_PORT}" 'cn=config'

  beluga_log "waiting for the replication target server ${REPL_DST_HOST}:${REPL_DST_LDAPS_PORT}"
  waitUntilLdapUp "${REPL_DST_HOST}" "${REPL_DST_LDAPS_PORT}" 'cn=config'
fi

# It is possible that the persistent volume where we are tracking replicated DNs is gone. In that case, we must
# delete this server from the topology registry. Check the source server before proceeding.
beluga_log "checking source server to see if this server must first be removed from the topology"
REMOVE_SERVER_FROM_TOPOLOGY_FIRST=false

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