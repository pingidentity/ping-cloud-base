#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"

test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"
test -f "${HOOKS_DIR}/pingdirectory.lib.sh" && . "${HOOKS_DIR}/pingdirectory.lib.sh"

########################################################################################################################
# Change the password of the provided user.
#
# Arguments
#   ${1} -> The DN of the user.
#   ${2} -> The file containing the new password file in clear text.
#   ${3} -> Any optional control to be used with the LDAP modify request.
#
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
# Add the base entry for USER_BASE_DN on the provided server. If no server is provided, then the user base entry will
# be added on this server.
#
# Arguments
#   ${1} ->  The optional target host to which to add the user base entry.
#
########################################################################################################################
add_base_entry_if_absent() {
  TARGET_HOST=${1}
  test -z "${TARGET_HOST}" && TARGET_HOST=$(hostname)

  # It may take the user backend a few seconds to initialize after the server is started
  USER_BASE_DN_EXISTS=false
  RETRY_COUNT=5

  for ATTEMPT in $(seq 1 "${RETRY_COUNT}"); do
    if ldapsearch --hostname "${TARGET_HOST}" --baseDN "${USER_BASE_DN}" --searchScope base '(&)' 1.1 &> /dev/null; then
      USER_BASE_DN_EXISTS=true
      echo "post-start: user base DN ${USER_BASE_DN} exists on ${TARGET_HOST}"
      break
    fi
    echo "post-start: attempt #${ATTEMPT} - user base DN ${USER_BASE_DN} does not exist on ${TARGET_HOST}"
    sleep 1s
  done

  if test "${USER_BASE_DN_EXISTS}" = 'false'; then
    echo "Adding user base entry ${USER_BASE_DN} on server ${TARGET_HOST}"
    run_hook 05-import-user-base-entries "${TARGET_HOST}"
  fi
}

echo "post-start: starting post-start hook"

# Remove the post-start initialization marker file so the pod isn't prematurely considered ready
POST_START_INIT_MARKER_FILE=/opt/out/instance/config/post-start-init-complete
rm -f "${POST_START_INIT_MARKER_FILE}"

echo "post-start: running ldapsearch test on this container (${HOSTNAME})"
waitUntilLdapUp "localhost" "${LDAPS_PORT}" 'cn=config'

echo "post-start: changing the cluster name to ${HOSTNAME}"
dsconfig --no-prompt set-server-instance-prop --instance-name "${HOSTNAME}" --set cluster-name:"${HOSTNAME}"

# FIXME:
# DS-41417: manage-profile replace-profile has a bug today where it won't make any changes to any local-db backends
# after setup. When manage-profile replace-profile is fixed, the following code block may be removed.

# Create the user backend, if it does not exist or update it to the right base DN
if ! ldapsearch --baseDN 'cn=config' --searchScope sub \
         "&(ds-cfg-backend-id=${USER_BACKEND_ID})(objectClass=ds-cfg-backend)" 1.1 &> /dev/null; then
  echo "post-start: backend ${USER_BACKEND_ID} does not exist - creating it"
  dsconfig --no-prompt create-backend \
    --type local-db \
    --backend-name "${USER_BACKEND_ID}" \
    --set "base-dn:${USER_BASE_DN}" \
    --set enabled:true \
    --set db-cache-percent:35
else
  echo "post-start: backend ${USER_BACKEND_ID} already exists - updating base DN to ${USER_BASE_DN}"
  dsconfig --no-prompt set-backend-prop \
    --backend-name "${USER_BACKEND_ID}" \
    --set "base-dn:${USER_BASE_DN}" \
    --set enabled:true \
    --set db-cache-percent:35
fi

backendUpdateStatus=$?
echo "post-start: backend ${USER_BACKEND_ID} update status: ${backendUpdateStatus}"
test ${backendUpdateStatus} -ne 0 && exit ${backendUpdateStatus}

# Change PF user passwords
PASS_FILE=$(mktemp)

echo "${PF_ADMIN_USER_PASSWORD}" > "${PASS_FILE}"
change_user_password 'uid=administrator,ou=admins,o=platformconfig' "${PASS_FILE}"
pwdModStatus=$?
test ${pwdModStatus} -ne 0 && exit ${pwdModStatus}

echo "${PF_LDAP_PASSWORD}" > "${PASS_FILE}"
change_user_password 'uid=pingfederate,ou=devopsaccount,o=platformconfig' "${PASS_FILE}"
pwdModStatus=$?
test ${pwdModStatus} -ne 0 && exit ${pwdModStatus}

# --- NOTE ---
# This assumes that data initialization is only required once for the initial data in the server profile.
# Subsequent initialization of data will be performed externally after populating one of the servers using data
# sync or some other mechanism, like import-ldif, followed by dsreplication initialize-all. This assumption may be
# different for each customer, but the script may be easily adjusted as appropriate for the customer's use case.

SHORT_HOST_NAME=$(hostname)
ORDINAL=$(echo ${SHORT_HOST_NAME##*-})
echo "post-start: pod ordinal: ${ORDINAL}"

if test ${ORDINAL} -eq 0; then
  # The request control allows encoded passwords, which is always required for topology admin users
  # ldapmodify allows a --passwordUpdateBehavior allow-pre-encoded-password=true to do the same
  ALLOW_PRE_ENCODED_PW_CONTROL='1.3.6.1.4.1.30221.2.5.51:true::MAOBAf8='
  change_user_password "cn=${ADMIN_USER_NAME}" "${ADMIN_USER_PASSWORD_FILE}" "${ALLOW_PRE_ENCODED_PW_CONTROL}"
  pwdModStatus=$?
  test ${pwdModStatus} -ne 0 && exit ${pwdModStatus}

  # Update the license file, if necessary
  LICENSE_FILE_PATH="${LICENSE_DIR}/${LICENSE_FILE_NAME}"

  if test -f "${LICENSE_FILE_PATH}"; then
    echo "post-start: updating product license from file ${LICENSE_FILE_PATH}"
    dsconfig --no-prompt set-license-prop --set "directory-platform-license-key<${LICENSE_FILE_PATH}"

    licModStatus=$?
    echo "post-start: product license update status: ${pwdModStatus}"
    test ${licModStatus} -ne 0 && exit ${licModStatus}
  fi

  touch "${POST_START_INIT_MARKER_FILE}"
  exit 0
fi

REPL_SETUP_MARKER_FILE=/opt/out/instance/config/repl-enabled

if grep -q "${USER_BASE_DN}" "${REPL_SETUP_MARKER_FILE}"; then
  echo "post-start: replication is already enabled for ${USER_BASE_DN}"
  touch "${POST_START_INIT_MARKER_FILE}"
  exit 0
fi

# It may take the user backend a few seconds to initialize after the server is started
USER_BASE_DN_EXISTS=false
RETRY_COUNT=5

for ATTEMPT in $(seq 1 "${RETRY_COUNT}"); do
  if ldapsearch --baseDN "${USER_BASE_DN}" --searchScope base '(&)' 1.1 &> /dev/null; then
    USER_BASE_DN_EXISTS=true
    echo "post-start: user base DN ${USER_BASE_DN} exists"
    break
  fi
  echo "post-start: attempt #${ATTEMPT} - user base DN ${USER_BASE_DN} does not exist"
  sleep 1s
done

# Bail dsreplication if user base entry is not present
if test "${USER_BASE_DN_EXISTS}" = 'false'; then
  echo "post-start: user base DN ${USER_BASE_DN} does not exist"
  touch "${POST_START_INIT_MARKER_FILE}"
  exit 0
fi

DOMAIN_NAME=$(hostname -f | cut -d'.' -f2-)
SRC_HOST="${K8S_STATEFUL_SET_NAME}-0.${DOMAIN_NAME}"

echo "post-start: running dsreplication enable for ${USER_BASE_DN}"
dsreplication enable \
  --retryTimeoutSeconds ${RETRY_TIMEOUT_SECONDS} \
  --trustAll \
  --host1 "${SRC_HOST}" --port1 "${LDAPS_PORT}" --useSSL1 \
  --bindDN1 "${ROOT_USER_DN}" --bindPasswordFile1 "${ROOT_USER_PASSWORD_FILE}" \
  --host2 "${HOSTNAME}" --port2 "${LDAPS_PORT}" --useSSL2 \
  --bindDN2 "${ROOT_USER_DN}" --bindPasswordFile2 "${ROOT_USER_PASSWORD_FILE}" \
  --replicationPort2 "${REPLICATION_PORT}" \
  --adminUID "${ADMIN_USER_NAME}" --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
  --no-prompt --ignoreWarnings \
  --baseDN "${USER_BASE_DN}" \
  --noSchemaReplication \
  --enableDebug --globalDebugLevel verbose

replEnableResult=$?
echo "post-start: replication enable for ${USER_BASE_DN} status: ${replEnableResult}"

if test ${replEnableResult} -eq 5; then
  echo "post-start: replication is already enabled for ${USER_BASE_DN} either directly or through a parent base DN"
  echo "${USER_BASE_DN}" >> "${REPL_SETUP_MARKER_FILE}"
  touch "${POST_START_INIT_MARKER_FILE}"
  exit 0
fi

if test ${replEnableResult} -ne 0; then
  echo "post-start: not running dsreplication initialize since enable failed with a non-successful return code"
  exit ${replEnableResult}
fi

echo "${USER_BASE_DN}" >> "${REPL_SETUP_MARKER_FILE}"

echo "post-start: running dsreplication initialize for ${USER_BASE_DN}"
dsreplication initialize \
  --retryTimeoutSeconds ${RETRY_TIMEOUT_SECONDS} \
  --trustAll \
  --hostSource "${SRC_HOST}" --portSource ${LDAPS_PORT} --useSSLSource \
  --hostDestination "${HOSTNAME}" --portDestination ${LDAPS_PORT} --useSSLDestination \
  --baseDN "${USER_BASE_DN}" \
  --adminUID "${ADMIN_USER_NAME}" \
  --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
  --no-prompt --ignoreWarnings \
  --enableDebug \
  --globalDebugLevel verbose

replInitResult=$?
echo "post-start: replication initialize for ${USER_BASE_DN} status: ${replInitResult}"

test ${replInitResult} -eq 0 && touch "${POST_START_INIT_MARKER_FILE}"
exit ${replInitResult}