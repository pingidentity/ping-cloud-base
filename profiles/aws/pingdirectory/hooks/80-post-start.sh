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

  echo "post-start: resetting password for user DN: ${USER_DN}"
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
  echo "post-start: password reset for DN ${USER_DN} status: ${pwdModStatus}"

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
# Sets the public/external hostname in the server's server.host file, if the PD_PUBLIC_HOSTNAME is set.
########################################################################################################################
function set_external_hostname() {
  if test ! -z "${PD_PUBLIC_HOSTNAME}"; then
    SERVER_HOST_FILE="${SERVER_ROOT_DIR}"/config/server.host
    echo "post-start: replacing the server hostname to ${PD_PUBLIC_HOSTNAME} in ${SERVER_HOST_FILE}"
    echo "hostname=${PD_PUBLIC_HOSTNAME}" > "${SERVER_HOST_FILE}"
  fi
}

########################################################################################################################
# Add the base entry for USER_BASE_DN on the provided server.
#
# Arguments
#   ${1} -> The target host to which to add the user base entry.
#   ${2} -> The target port.
########################################################################################################################
add_base_entry() {
  COMPUTED_DOMAIN=$(echo "${USER_BASE_DN}" | sed 's/^dc=\([^,]*\).*/\1/')
  COMPUTED_ORG=$(echo "${USER_BASE_DN}" | sed 's/^o=\([^,]*\).*/\1/')

  USER_BASE_ENTRY_LDIF=$(mktemp)

  if ! test "${USER_BASE_DN}" = "${COMPUTED_DOMAIN}"; then
    cat > "${USER_BASE_ENTRY_LDIF}" <<EOF
dn: ${USER_BASE_DN}
objectClass: top
objectClass: domain
dc: ${COMPUTED_DOMAIN}
EOF
  elif ! test "${USER_BASE_DN}" = "${COMPUTED_ORG}"; then
    cat > "${USER_BASE_ENTRY_LDIF}" <<EOF
dn: ${USER_BASE_DN}
objectClass: top
objectClass: organization
o: ${COMPUTED_DOMAIN}
EOF
  else
    echo "post-start: user base DN must be 1-level deep in one of these formats: dc=<domain>,dc=com or o=<org>,dc=com"
    return 80
  fi

  # Append some required ACIs to the base entry file. Without these, PF SSO will not work.
  cat >> "${USER_BASE_ENTRY_LDIF}" <<EOF
aci: (targetattr!="userPassword")(version 3.0; acl "Allow anonymous read access for anyone"; allow (read,search,compare) userdn="ldap:///anyone";)
aci: (targetattr!="userPassword")(version 3.0; acl "Allow self-read access to all user attributes except the password"; allow (read,search,compare) userdn="ldap:///self";)
aci: (targetattr="*")(version 3.0; acl "Allow users to update their own entries"; allow (write) userdn="ldap:///self";)
aci: (targetattr="*")(version 3.0; acl "Grant full access for the admin user"; allow (all) userdn="ldap:///uid=admin,${USER_BASE_DN}";)
EOF

  echo "post-start: contents of ${USER_BASE_ENTRY_LDIF}:"
  cat "${USER_BASE_ENTRY_LDIF}"

  TARGET_HOST=${1}
  TARGET_PORT=${2}

  echo "post-start: adding user entry in ${USER_BASE_ENTRY_LDIF} on ${TARGET_HOST}:${TARGET_PORT}"
  ldapmodify --defaultAdd --hostname "${TARGET_HOST}" --port "${TARGET_PORT}" --ldifFile "${USER_BASE_ENTRY_LDIF}"

  modifyStatus=$?
  echo "post-start: add user base entry status: ${modifyStatus}"

  return "${modifyStatus}"
}

########################################################################################################################
# Check if the base entry for USER_BASE_DN exists on the provided server.
#
# Arguments
#   ${1} -> The target host to check.
#   ${2} -> The target port.
########################################################################################################################
does_base_entry_exist() {
  TARGET_HOST=${1}
  TARGET_PORT=${2}

  # It may take the user backend a few seconds to initialize after the server is started
  RETRY_COUNT=5

  for ATTEMPT in $(seq 1 "${RETRY_COUNT}"); do
    if ldapsearch --hostname "${TARGET_HOST}" --port "${TARGET_PORT}" \
           --baseDN "${USER_BASE_DN}" --searchScope base '(&)' 1.1 &> /dev/null; then
      echo "post-start: user base entry ${USER_BASE_DN} exists on ${TARGET_HOST}:${TARGET_PORT}"
      return 0
    fi
    echo "post-start: attempt #${ATTEMPT} - user base entry ${USER_BASE_DN} does not exist on ${TARGET_HOST}:${TARGET_PORT}"
    sleep 1s
  done

  echo "post-start: user base entry ${USER_BASE_DN} does not exist on ${TARGET_HOST}:${TARGET_PORT}"
  return 1
}

########################################################################################################################
# Add the USER_BASE_DN on the provided server to the user backend, creating the user backend if it isn't already
# present.
#
# Arguments
#   ${1} -> The target host whose user backend to configure.
#   ${2} -> The target port.
########################################################################################################################
configure_user_backend() {
  TARGET_HOST=${1}
  TARGET_PORT=${2}

  # Create the user backend, if it does not exist or update it to the right base DN
  if ! ldapsearch --hostname "${TARGET_HOST}" --port "${TARGET_PORT}" --baseDN 'cn=config' --searchScope sub \
           "&(ds-cfg-backend-id=${USER_BACKEND_ID})(objectClass=ds-cfg-backend)" 1.1 &> /dev/null; then
    echo "post-start: backend ${USER_BACKEND_ID} does not exist on ${TARGET_HOST}:${TARGET_PORT} - creating it"
    dsconfig --no-prompt create-backend \
      --hostname "${TARGET_HOST}" --port "${TARGET_PORT}" \
      --type local-db \
      --backend-name "${USER_BACKEND_ID}" \
      --set "base-dn:${USER_BASE_DN}" \
      --set enabled:true \
      --set db-cache-percent:35
  else
    echo "post-start: backend ${USER_BACKEND_ID} exists on ${TARGET_HOST}:${TARGET_PORT} - adding base DN ${USER_BASE_DN} to it"
    dsconfig --no-prompt set-backend-prop \
      --hostname "${TARGET_HOST}" --port "${TARGET_PORT}" \
      --backend-name "${USER_BACKEND_ID}" \
      --add "base-dn:${USER_BASE_DN}" \
      --set enabled:true \
      --set db-cache-percent:35
  fi

  updateStatus=$?
  echo "post-start: backend ${USER_BACKEND_ID} update status for ${USER_BASE_DN} on ${TARGET_HOST}:${TARGET_PORT}: ${updateStatus}"
  return ${updateStatus}
}

########################################################################################################################
# Sets the force-as-master-for-mirrored-data flag in global configuration to the provided value on the seed server.
#
# Arguments
#   ${1} -> The value of the force-as-master flag, i.e. true or false. Defaults to false.
########################################################################################################################
set_force_as_master() {
  FORCE_FLAG="${1:-false}"

  echo "post-start: setting force-as-master on server ${SEED_HOST}:${SEED_PORT} to ${FORCE_FLAG}"
  dsconfig --no-prompt --hostname "${SEED_HOST}" --port "${SEED_PORT}" \
      set-global-configuration-prop --set "force-as-master-for-mirrored-data:${FORCE_FLAG}"
  status=$?

  echo "post-start: status of setting force-as-master on server ${SEED_HOST}:${SEED_PORT} to ${FORCE_FLAG}: ${status}"
  return ${status}
}

########################################################################################################################
# Resets the force-as-master flag to false on the provided server if REMOVE_SERVER_FROM_TOPOLOGY_FIRST is true.
########################################################################################################################
reset_force_as_master() {
  if test ! -z "${REMOVE_SERVER_FROM_TOPOLOGY_FIRST}" && test "${REMOVE_SERVER_FROM_TOPOLOGY_FIRST}" = 'true'; then
    echo "post-start: resetting force-as-master to false before stopping this server"
    set_force_as_master false
  fi
}

########################################################################################################################
# Create a topology file with the seed server and this server. The name of the topology file will be available in
# the variable TOPOLOGY_FILE after this method is invoked.
########################################################################################################################
create_topology_file() {
  TOPOLOGY_FILE=/tmp/topology.json

  rm -f "${TOPOLOGY_FILE}"
  manage-topology export --exportFilePath "${TOPOLOGY_FILE}" --complexityLevel expert
  LOCAL_SERVER_INSTANCE=$(jq --arg INSTANCE_NAME "${INSTANCE_NAME}" \
      '.serverInstances[] | select(.instanceName == $INSTANCE_NAME)' < "${TOPOLOGY_FILE}")

  rm -f "${TOPOLOGY_FILE}"
  manage-topology export --hostname "${SEED_HOST}" --port "${SEED_PORT}" \
      --exportFilePath "${TOPOLOGY_FILE}" --complexityLevel expert
  SRC_SERVER_INSTANCE=$(jq --arg INSTANCE_NAME_SRC_HOST "${INSTANCE_NAME_SRC_HOST}" \
      '.serverInstances[] | select(.instanceName == $INSTANCE_NAME_SRC_HOST)' < "${TOPOLOGY_FILE}")

  echo "{ \"serverInstances\" : [ ${SRC_SERVER_INSTANCE}, ${LOCAL_SERVER_INSTANCE} ] }" > "${TOPOLOGY_FILE}"
}

########################################################################################################################
# Removes this server from the replication topology.
########################################################################################################################
remove_server_from_topology() {
  echo "post-start: removing ${HOSTNAME} (instance name: ${INSTANCE_NAME}) from the topology"
  remove-defunct-server --no-prompt \
    --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
    --topologyFilePath "${TOPOLOGY_FILE}" \
    --serverInstanceName "${INSTANCE_NAME}" \
    --ignoreOnline \
    --bindDN "${ROOT_USER_DN}" \
    --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --enableDebug --globalDebugLevel verbose
  status=$?

  if test ${status} -ne 0; then
    echo "post-start: contents of remove-defunct-server.log:"
    cat "${SERVER_ROOT_DIR}"/logs/tools/remove-defunct-server.log
  fi

  echo "post-start: server removal exited with return code: ${status}"
  return ${status}
}

########################################################################################################################
# Disable replication for the provided base DN on this server.
#
# Arguments
#   ${1} -> The base DN for which to disable replication.
########################################################################################################################
disable_replication_for_dn() {
  BASE_DN=${1}

  echo "post-start: disabling replication for base DN ${BASE_DN}"
  dsreplication disable \
    --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
    --trustAll \
    --hostname "${HOSTNAME}" --port "${LDAPS_PORT}" --useSSL \
    --adminUID "${ADMIN_USER_NAME}" --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
    --baseDN "${BASE_DN}" \
    --no-prompt --ignoreWarnings \
    --enableDebug --globalDebugLevel verbose
  replDisableResult=$?
  echo "post-start: replication disable for ${BASE_DN} status: ${replDisableResult}"

  if test ${replDisableResult} -ne 0; then
    echo "post-start: contents of dsreplication.log:"
    cat "${SERVER_ROOT_DIR}"/logs/tools/dsreplication.log

    if test ${replDisableResult} -eq 6; then
      echo "post-start: replication is currently not enabled for base DN ${BASE_DN}"
      return 0
    fi
  fi

  return ${replDisableResult}
}

########################################################################################################################
# Enable a LDAPS connection handler at the provided port on localhost.
#
# Arguments
#   ${1} -> The port on which to add an LDAPS connection handler on localhost.
########################################################################################################################
enable_ldap_connection_handler() {
  PORT=${1}

  echo "post-start: enabling LDAPS connection handler at port ${PORT}"
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
  echo "post-start: LDAPS enable at port ${PORT} status: ${result}"

  if test ${result} -eq 68; then
    echo "post-start: LDAPS connection handler already exists at port ${PORT}"
    return 0
  fi

  return "${result}"
}

########################################################################################################################
# Enable replication for the provided base DN on this server.
#
# Arguments
#   ${1} -> The base DN for which to enable replication.
########################################################################################################################
enable_replication_for_dn() {
  BASE_DN=${1}

  # FIXME: DS-41417: manage-profile replace-profile has a bug today where it won't make any changes to any local-db
  # backends after setup. When manage-profile replace-profile is fixed, the following code block may be removed.
  if test "${BASE_DN}" = "${USER_BASE_DN}"; then
    echo "post-start: user base DN ${USER_BASE_DN} is uninitialized"

    for HOST_PORT in "${REPL_SRC_HOST}:${REPL_SRC_LDAPS_PORT}" "${REPL_DST_HOST}:${REPL_DST_LDAPS_PORT}"; do
      HOST=${HOST_PORT%:*}
      PORT=${HOST_PORT#*:}

      configure_user_backend "${HOST}" "${PORT}"
      result=$?
      test ${result} -ne 0 && return ${result}

      does_base_entry_exist "${HOST}" "${PORT}"
      if test $? -ne 0; then
        add_base_entry "${HOST}" "${PORT}"
        result=$?
        test ${result} -ne 0 && return ${result}
      fi
    done
  fi

  echo "post-start: running dsreplication enable for ${BASE_DN}"
  dsreplication enable \
    --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
    --trustAll \
    --host1 "${REPL_SRC_HOST}" --port1 "${REPL_SRC_LDAPS_PORT}" --useSSL1 \
    --bindDN1 "${ROOT_USER_DN}" --bindPasswordFile1 "${ROOT_USER_PASSWORD_FILE}" \
    --replicationPort1 "${REPL_SRC_REPL_PORT}" \
    --host2 "${REPL_DST_HOST}" --port2 "${REPL_DST_LDAPS_PORT}" --useSSL2 \
    --bindDN2 "${ROOT_USER_DN}" --bindPasswordFile2 "${ROOT_USER_PASSWORD_FILE}" \
    --replicationPort2 "${REPL_DST_REPL_PORT}" \
    --adminUID "${ADMIN_USER_NAME}" --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
    --no-prompt --ignoreWarnings \
    --baseDN "${BASE_DN}" \
    --noSchemaReplication \
    --enableDebug --globalDebugLevel verbose
  replEnableResult=$?
  echo "post-start: replication enable for ${BASE_DN} status: ${replEnableResult}"

  if test ${replEnableResult} -ne 0; then
    echo "post-start: contents of dsreplication.log:"
    cat "${SERVER_ROOT_DIR}"/logs/tools/dsreplication.log
  fi

  return ${replEnableResult}
}

########################################################################################################################
# Initialize replication for the provided base DN on this server.
#
# Arguments
#   ${1} -> The base DN for which to initialize replication.
########################################################################################################################
initialize_replication_for_dn() {
  BASE_DN=${1}

  # If multi-cluster, initialize the first server in the child cluster from the first server in the parent cluster.
  # Initialize other servers in the child cluster from the first server within the same cluster.
  if "${IS_MULTI_CLUSTER}" && test "${ORDINAL}" -eq 0; then
    FROM_HOST="${PD_PARENT_PUBLIC_HOSTNAME}"
    FROM_PORT=6360
  else
    FROM_HOST="${K8S_STATEFUL_SET_NAME}-0.${DOMAIN_NAME}"
    FROM_PORT="${LDAPS_PORT}"
  fi

  TO_HOST="${K8S_STATEFUL_SET_NAME}-${ORDINAL}.${DOMAIN_NAME}"
  TO_PORT="${LDAPS_PORT}"

  echo "post-start: running dsreplication initialize for ${BASE_DN} from ${FROM_HOST}:${FROM_PORT} to ${TO_HOST}:${TO_PORT}"
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
  echo "post-start: replication initialize for ${BASE_DN} status: ${replInitResult}"

  if test ${replInitResult} -ne 0; then
    echo "post-start: contents of dsreplication.log:"
    cat "${SERVER_ROOT_DIR}"/logs/tools/dsreplication.log
  fi

  return ${replInitResult}
}

########################################################################################################################
# Resets the force-as-master flag to false on the source or seed server if REMOVE_SERVER_FROM_TOPOLOGY_FIRST is true.
# Then, stop the container to signal failure with the post-start sequence.
########################################################################################################################
stop_container() {
  reset_force_as_master
  echo "post-start: stopping the container to signal failure with post-start sequence"
  stop-server
}


# --- MAIN SCRIPT ---
echo "post-start: starting post-start hook"

echo "post-start: running ldapsearch test on this container (${HOSTNAME})"
waitUntilLdapUp localhost "${LDAPS_PORT}" 'cn=config'

SHORT_HOST_NAME=$(hostname)
DOMAIN_NAME=$(hostname -f | cut -d'.' -f2-)
ORDINAL=${SHORT_HOST_NAME##*-}

echo "post-start: pod ordinal: ${ORDINAL}"

# Determine if this a cross-cluster deployment, and if so whether this is the parent cluster.
IS_MULTI_CLUSTER=false
IS_PARENT_CLUSTER=false

if is_multi_cluster; then
  IS_MULTI_CLUSTER=true
  test "${PD_PARENT_PUBLIC_HOSTNAME}" = "${PD_PUBLIC_HOSTNAME}" && IS_PARENT_CLUSTER=true
fi

echo "post-start: multi-cluster: ${IS_MULTI_CLUSTER}; parent-cluster: ${IS_PARENT_CLUSTER}"

echo "post-start: getting server instance name from global config"
INSTANCE_NAME=$(dsconfig --no-prompt get-global-configuration-prop \
    --property instance-name --script-friendly | awk '{ print $2 }')
echo "post-start: server instance name from global config: ${INSTANCE_NAME}"

# Add an LDAPS connection handler for external access, if necessary
if test ! -z "${PD_PUBLIC_HOSTNAME}"; then
  EXTERNAL_LDAPS_PORT="636${ORDINAL}"
  enable_ldap_connection_handler "${EXTERNAL_LDAPS_PORT}"
  test $? -ne 0 && stop_container

  # Change the hostname in the server instance to the external one
  dsconfig --no-prompt set-server-instance-prop \
      --instance-name "${INSTANCE_NAME}" \
      --set hostname:"${PD_PUBLIC_HOSTNAME}" \
      --set ldaps-port:"${EXTERNAL_LDAPS_PORT}"
  result=$?
  echo "post-start: change hostname/port: ${result}"
  test $? -ne 0 && stop_container

  dsconfig --no-prompt set-server-instance-listener-prop \
      --instance-name "${INSTANCE_NAME}" \
      --listener-name ldap-listener-mirrored-config \
      --set server-ldap-port:"${EXTERNAL_LDAPS_PORT}"
  result=$?
  echo "post-start: change LDAP listener port: ${result}"
  test $? -ne 0 && stop_container
fi

# Change PF user passwords
change_pf_user_passwords
test $? -ne 0 && stop_container

if test "${ORDINAL}" -eq 0 && test "${IS_PARENT_CLUSTER}" = 'true'; then
  # The request control allows encoded passwords, which is always required for topology admin users
  # ldapmodify allows a --passwordUpdateBehavior allow-pre-encoded-password=true to do the same
  ALLOW_PRE_ENCODED_PW_CONTROL='1.3.6.1.4.1.30221.2.5.51:true::MAOBAf8='
  change_user_password "cn=${ADMIN_USER_NAME}" "${ADMIN_USER_PASSWORD_FILE}" "${ALLOW_PRE_ENCODED_PW_CONTROL}"
  test $? -ne 0 && stop_container

  # Update the license file, if necessary
  LICENSE_FILE_PATH="${LICENSE_DIR}/${LICENSE_FILE_NAME}"

  if test -f "${LICENSE_FILE_PATH}"; then
    echo "post-start: updating product license from file ${LICENSE_FILE_PATH}"
    dsconfig --no-prompt set-license-prop --set "directory-platform-license-key<${LICENSE_FILE_PATH}"

    licModStatus=$?
    echo "post-start: product license update status: ${pwdModStatus}"
    test ${licModStatus} -ne 0 && stop_container
  fi

  echo "post-start: post-start complete"
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
echo "post-start: replication base DNs: ${DNS_TO_INITIALIZE}"

UNINITIALIZED_DNS=
for DN in ${DNS_TO_INITIALIZE}; do
  if grep -q "${DN}" "${REPL_INIT_MARKER_FILE}" &> /dev/null; then
    echo "post-start: replication is already initialized for ${DN}"
  else
    test -z "${UNINITIALIZED_DNS}" &&
        UNINITIALIZED_DNS="${DN}" ||
        UNINITIALIZED_DNS="${UNINITIALIZED_DNS} ${DN}"
  fi
done

# All base DNs are already initialized, so we're good.
if test -z "${UNINITIALIZED_DNS}"; then
  echo "post-start: replication is already initialized for all base DNs: ${DNS_TO_INITIALIZE}"
  echo "post-start: post-start complete"
  exit
fi

# Determine the hostnames and ports to use while enabling replication. When in multi-cluster mode and not in the
# parent cluster, use the external names and ports. Otherwise, use internal names and ports.
if "${IS_MULTI_CLUSTER}"; then
  REPL_SRC_HOST="${PD_PARENT_PUBLIC_HOSTNAME}"
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

echo "post-start: using REPL_SRC_HOST: ${REPL_SRC_HOST}"
echo "post-start: using REPL_SRC_LDAPS_PORT: ${REPL_SRC_LDAPS_PORT}"
echo "post-start: using REPL_SRC_REPL_PORT: ${REPL_SRC_REPL_PORT}"
echo "post-start: using REPL_DST_HOST: ${REPL_DST_HOST}"
echo "post-start: using REPL_DST_LDAPS_PORT: ${REPL_DST_LDAPS_PORT}"
echo "post-start: using REPL_DST_REPL_PORT: ${REPL_DST_REPL_PORT}"

# If in multi-region mode, wait for the replication source and target servers to be up and running through the
# load balancer before enabling/initializing replication.
if "${IS_MULTI_CLUSTER}"; then
  echo "post-start: waiting for the replication seed server ${REPL_SRC_HOST}:${REPL_SRC_LDAPS_PORT}"
  waitUntilLdapUp "${REPL_SRC_HOST}" "${REPL_SRC_LDAPS_PORT}" 'cn=config'

  echo "post-start: waiting for the replication target server ${REPL_DST_HOST}:${REPL_DST_LDAPS_PORT}"
  waitUntilLdapUp "${REPL_DST_HOST}" "${REPL_DST_LDAPS_PORT}" 'cn=config'
fi

# It is possible that the persistent volume where we are tracking replicated DNs is gone. In that case, we must
# delete this server from the topology registry. Check the source server before proceeding.
echo "post-start: checking source server to see if this server must first be removed from the topology"
REMOVE_SERVER_FROM_TOPOLOGY_FIRST=false

if ldapsearch --hostname "${SEED_HOST}" --port "${SEED_PORT}" \
      --baseDN 'cn=topology,cn=config' --searchScope sub \
      "(ds-cfg-server-instance-name=${INSTANCE_NAME})" 1.1 2>/dev/null | grep ^dn; then
  echo "post-start: the server is partially present in the topology registry and must be removed first"
  REMOVE_SERVER_FROM_TOPOLOGY_FIRST=true

  echo "post-start: getting source server instance name from global config"
  INSTANCE_NAME_SRC_HOST=$(dsconfig --no-prompt get-global-configuration-prop \
      --useSSL --trustAll \
      --hostname "${SEED_HOST}" --port "${SEED_PORT}" \
      --property instance-name --script-friendly | awk '{ print $2 }')

  echo "post-start: creating a topology file with the source server ${SEED_HOST}:${SEED_PORT} and this server"
  create_topology_file

  # Force seed server as the master so the topology registry is guaranteed to be writable. Forgive the failure here
  # and let it fail downstream if there are topology write failures.
  echo "post-start: forcing seed server ${SEED_HOST}:${SEED_PORT} as topology master"
  set_force_as_master true

  echo "post-start: removing server from the topology"
  remove_server_from_topology
  test $? -ne 0 && stop_container
else
  echo "post-start: the server does not already exist in the topology, so does not need to be removed first"
fi

echo "post-start: replication will be initialized for base DNs: ${UNINITIALIZED_DNS}"

# For end-user base DNs, allow the option to disable previous DNs from replication. This allows
# customers to disable the OOTB base DN that is automatically enabled and initialized.
if test "${DISABLE_ALL_OLDER_USER_BASE_DN}" = 'true'; then
  ENABLED_USER_BASE_DNS=$(ldapsearch --baseDN 'cn=config' --searchScope sub \
      "&(ds-cfg-backend-id=${USER_BACKEND_ID})(objectClass=ds-cfg-backend)" ds-cfg-base-dn |
      grep '^ds-cfg-base-dn' | cut -d: -f2 | tr -d ' ')

  for DN in ${ENABLED_USER_BASE_DNS}; do
    # Do not disable the current USER_BASE_DN. All others are candidates.
    if test "${DN}" != "${USER_BASE_DN}"; then
      disable_replication_for_dn "${DN}"
      test $? -eq 0 &&
          sed -i.bak -E "/${DN}/d" "${REPL_INIT_MARKER_FILE}"
    fi
  done
fi

for DN in ${UNINITIALIZED_DNS}; do
  enable_replication_for_dn "${DN}"
  replEnableResult=$?

  # We will tolerate error code 5. It it likely when the user base DN does not exist on the source server.
  # For example, this can happen when the user base DN is updated after initial setup.
  if test ${replEnableResult} -eq 5; then
    echo "post-start: replication cannot be enabled for ${DN} or may already be enabled - will try initialization"
  elif test ${replEnableResult} -ne 0; then
    echo "post-start: not running dsreplication initialize since enable failed with a non-successful return code"
    stop_container
  fi

  initialize_replication_for_dn "${DN}"
  replInitResult=$?

  if test ${replInitResult} -eq 0; then
    echo "post-start: adding DN ${DN} to the replication marker file ${REPL_INIT_MARKER_FILE}"
    echo "${DN}" >> "${REPL_INIT_MARKER_FILE}"
  else
    stop_container
  fi
done

# Reset the force-as-master flag to false on the seed server if it was set before.
reset_force_as_master

echo "post-start: post-start complete"