#!/usr/bin/env sh

${VERBOSE} && set -x

ADMIN_USER_DN="cn=${ADMIN_USER_NAME},cn=Topology Admin Users,cn=Topology,cn=config"
CONFIG_FILE="${SERVER_ROOT_DIR}/config/config.ldif"

PASSWORD_ATTR=userpassword
SEARCH_RESULT=$(ldifsearch --baseDN "${ADMIN_USER_DN}" --ldifFile "${CONFIG_FILE}" '(&)' "${PASSWORD_ATTR}")

if test ! -z "${SEARCH_RESULT}"; then
    echo "Found replication admin username: ${ADMIN_USER_NAME}"

    CURRENT_PASSWORD=$(echo "${SEARCH_RESULT#dn: ${ADMIN_USER_DN}}" |
        cut -d: -f2 | xargs | tr -d '[:blank:]')
    DO_PASSWORDS_MATCH=$(encode-password \
        --clearPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
        --encodedPassword "${CURRENT_PASSWORD}")

    if echo "${DO_PASSWORDS_MATCH}" | grep 'passwords match'; then
      echo "Not changing password for username: ${ADMIN_USER_NAME}"
      exit 0
    fi

    ENCODED_PASSWORD=$(encode-password \
        --clearPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
        --storageScheme PBKDF2 | cut -d: -f2 | xargs | tr -d \')

    CHANGES_FILE=$(mktemp)
    cat > "${CHANGES_FILE}" <<EOF
dn: ${ADMIN_USER_DN}
changeType: modify
replace: ${PASSWORD_ATTR}
${PASSWORD_ATTR}: ${ENCODED_PASSWORD}
EOF

    CONFIG_FILE_NEW="${CONFIG_FILE}.new"
    echo "Applying changes in ${CHANGES_FILE} to ${CONFIG_FILE_NEW}"

    ldifmodify --changesLDIF "${CHANGES_FILE}" \
        --sourceLDIF "${CONFIG_FILE}" \
        --targetLDIF "${CONFIG_FILE_NEW}"
    MODIFY_STATUS=${?}

    if test ${MODIFY_STATUS} -eq 0; then
      echo "Replacing ${CHANGES_FILE} with ${CONFIG_FILE_NEW}"
      mv "${CONFIG_FILE_NEW}" "${CONFIG_FILE}"
    else
      echo "Error applying changes in ${CHANGES_FILE} to ${CONFIG_FILE_NEW}"
    fi

    exit ${MODIFY_STATUS}
else
  echo "Admin user ${ADMIN_USER_NAME} not found"
  exit 0
fi