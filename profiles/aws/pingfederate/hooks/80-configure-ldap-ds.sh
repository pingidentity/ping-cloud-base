#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- Copies the server bits from the image into the SERVER_ROOT_DIR if
#- it is a new fresh container.
#

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"


TEMPLATES_DIR_PATH="${STAGING_DIR}"/templates/ldap-ds
PF_API_HOST="https://${PF_ADMIN_HOST_PORT}/pf-admin-api/v1"

get_datastore() {
  DATA_STORES_RESPONSE=$(make_api_request -s -X GET "${PF_API_HOST}/dataStores/${LDAP_DS_ID}") > /dev/null
}

update_datastore() {
  export PF_LDAP_PASSWORD_OBFUSCATED=$(sh ${SERVER_ROOT_DIR}/bin/obfuscate.sh "${PF_LDAP_PASSWORD}" | tr -d '\n')

  wait_for_admin_api_endpoint

  # Inject obfuscated password into ldap properties file.
  vars='${PF_PD_BIND_USESSL}
${PD_CLUSTER_PRIVATE_HOSTNAME}
${PF_LDAP_PASSWORD}
${PF_PD_BIND_PORT}
${LDAP_DS_ID}'

  LDAP_DS_PAYLOAD=$(envsubst "${vars}" < "${TEMPLATES_DIR_PATH}/pd-ldap-ds.json")

  if get_datastore; then
    beluga_log "PD LDAP Data Store exists, updating with current password."
    make_api_request -X PUT -d "${LDAP_DS_PAYLOAD}" \
      "${PF_API_HOST}/dataStores/${LDAP_DS_ID}" > /dev/null
    test $? -ne 0 && return 1
  else
    beluga_log "PD LDAP Data Store isn't there, adding it."
    make_api_request -X POST -d "${LDAP_DS_PAYLOAD}" \
      "${PF_API_HOST}/dataStores" > /dev/null
    test $? -ne 0 && return 1
  fi

  return 0
}

update_datastore

