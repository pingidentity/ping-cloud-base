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
# Initialize replication for the provided base DN on this server.
#
# Arguments
#   ${1} -> The base DN for which to initialize replication.
#   ${2} -> An optional timeout (in seconds) for the dsreplication initialize command. If not provided, then a timeout
#           of 0 is assumed, which implies no retries. This argument is intended only for internal use from within the
#           function.
########################################################################################################################
initialize_server_for_dn() {
  local base_dn=${1}
  local timeout_seconds=${2:-0}

  # Initialize the first server in the secondary cluster from the first server in the primary cluster

  # Note: The variable 'from_service_host_name' is used to get the hostname from pingdirectory k8s service.
  # The variable PD_CLUSTER_PUBLIC_HOSTNAME is set to the primary region pingdirectory k8s service.
  # The problem is this variable retrieves the primary region hostname only and there's no way to do this for the
  # secondary regions. There is additional logic that attempts to build the service hostname
  # by concatenating 'pingdirectory-cluster.${DNS_ZONE}. DNS_ZONE is dynamic and is set by region.
  # This can possibly be refactored after mono-repo changes.
  if is_secondary_cluster && test "${ORDINAL}" -eq 0; then
    local from_host="${K8S_STATEFUL_SET_NAME}-0.${PD_CLUSTER_PUBLIC_HOSTNAME}"
    local from_running_pod_name="${K8S_STATEFUL_SET_NAME}-0"
    # Retrieve the primary service hostname
    local from_service_host_name="${PD_CLUSTER_PUBLIC_HOSTNAME}"
  else

    # Retrieve the pingdirectory secondary service hostname if its multi-cluster
    if is_multi_cluster; then
      local from_service_host_name="pingdirectory-cluster.${DNS_ZONE}"
    else
      # If this is not a multi-cluster environment the use the k8s pingdirectory service internal network
      local from_service_host_name="${LOCAL_DOMAIN_NAME}"
    fi

    # Initialize all other servers a first successful running server within the same cluster
    other_successful_pingdirectory_pods=$(get_other_running_pingdirectory_pods)
    if test -z "${other_successful_pingdirectory_pods}"; then
      beluga_error "Something went wrong as there are no other successful pods to get replicated data FROM"
      return 1
    fi
    local from_running_pod_name=$(echo "${other_successful_pingdirectory_pods}" | head -n 1)
    local from_host="${from_running_pod_name}.${LOCAL_DOMAIN_NAME}"
  fi
  local from_port="${PD_LDAPS_PORT}"

  # Before calling replication initialize, ensure that the FROM server replication connection is established
  # using the available attribute. This attribute will be logged as true. We found that dsreplication initialize
  # will timeout without any detailed errors. After research we found it to be that connection wasn't established.
  # Until, STAGING-20891 is resolved we will need to keep this workaround.
  beluga_log "Verifying that server with ${base_dn} from ${from_running_pod_name} at host ${from_service_host_name} replication connection is available"

  local is_base_dn_from_pod_replication_connection_ready=$(ldapsearch \
    --outputFormat values-only \
    --baseDN "cn=monitor" \
    --scope sub "(&(objectClass=ds-replication-server-handler-monitor-entry)(replication-server=${from_running_pod_name}.${from_service_host_name}*)(cn=Remote Repl Server ${base_dn}*))" available |\
      tr '[:upper:]' '[:lower:]')

  if test -z "${is_base_dn_from_pod_replication_connection_ready}"; then
    beluga_error "Something went wrong as there is no FROM replication service found within PingDirectory cn=monitor"
    return 1
  fi

  if [ "${is_base_dn_from_pod_replication_connection_ready}" != "true" ]; then
    beluga_warn "Server with ${base_dn} from ${from_running_pod_name} at host ${from_service_host_name} replication connection wasn't available Will wait and try again"
    sleep 15
    # Try again using the same base DN
    initialize_server_for_dn "${base_dn}"
    return $?
  fi

  local to_host="${K8S_STATEFUL_SET_NAME}-${ORDINAL}.${LOCAL_DOMAIN_NAME}"
  local to_port="${PD_LDAPS_PORT}"

  beluga_log "running dsreplication initialize for ${base_dn} from ${from_host}:${from_port} to ${to_host}:${to_port}"
  dsreplication initialize \
    --trustAll \
    --hostSource "${from_host}" --portSource "${from_port}" --useSSLSource \
    --hostDestination "${to_host}" --portDestination "${to_port}" --useSSLDestination \
    --retryTimeoutSeconds "${timeout_seconds}" \
    --baseDN "${base_dn}" \
    --adminUID "${ADMIN_USER_NAME}" \
    --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
    --no-prompt --ignoreWarnings \
    --enableDebug \
    --globalDebugLevel verbose \
    --DPINGDIR_CLI_BYPASS_TOPOLOGY_VERSION_CHECK=true
  replInitResult=$?
  beluga_log "replication initialize for ${base_dn} status: ${replInitResult}"

  # Tolerate return code 7 - this means that the base DN does not exist on the source server.
  # When the source server is rolled out, it'll initialize replication to all servers for all DNs.
  if test ${replInitResult} -eq 7; then
    beluga_warn "base DN does not exist on this server - the seed server will initialize this server when it's rolled"
    return 0
  fi

  if test ${replInitResult} -ne 0; then
    beluga_log "contents of dsreplication.log:"
    cat "${SERVER_ROOT_DIR}"/logs/tools/dsreplication.log

    # If it was an initial call to initialize, then try to initialize again with a retry timeout.
    if test "${timeout_seconds}" -eq 0 && test "${RETRY_TIMEOUT_SECONDS}" -ne 0; then
      initialize_server_for_dn "${base_dn}" "${RETRY_TIMEOUT_SECONDS}"
      replInitResult=$?
    fi
  fi

  return ${replInitResult}
}

capture_latest_logs() {
  msg="${1}"
  status_code=${2}

  beluga_error "${msg}: ${status_code}"
  beluga_error "The following contains logs from the ${SERVER_ROOT_DIR}/logs/config-audit.log file:"
  tail -100 "${SERVER_ROOT_DIR}/logs/config-audit.log"

  beluga_error "The following contains logs from the ${SERVER_ROOT_DIR}/logs/errors file:"
  tail -100 "${SERVER_ROOT_DIR}/logs/errors"
}

########################################################################################################################
# Perform finalization on exit.
# - On non-zero exit, stop the container to signal failure with the post-start sequence.
# - On success:
#   - Add the marker file signaling that post-start is complete
########################################################################################################################
finalize() {
  if test $? -ne 0; then
    beluga_error "stopping the container to signal failure with post-start sequence"
    stop-server
  fi

  touch "${POST_START_INIT_MARKER_FILE}"
  beluga_log "post-start complete"
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
# If this pingdirectory pod is a first time deployment and who is a child non-seed server
# then, run dsreplication initialize where it will get replicated data from another successful
# running pingdirectory pod
if is_first_time_deploy_child_server; then
  beluga_log "replication will be initialized for base DNs: ${DNS_TO_ENABLE}"
  for DN in ${DNS_TO_ENABLE}; do
    initialize_server_for_dn "${DN}"
    replInitResult=$?

    if test ${replInitResult} -ne 0; then
      exit 1
    fi
  done
fi

exit 0