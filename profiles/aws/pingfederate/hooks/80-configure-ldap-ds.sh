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


PF_API_404_MESSAGE="HTTP status code: 404"
TEMPLATES_DIR_PATH="${STAGING_DIR}"/templates/ldap-ds
PF_API_HOST="https://${PF_ADMIN_HOST_PORT}/pf-admin-api/v1"

# We hard code the DS for use in other configuration elements
LDAP_DS_ID="LDAP-FA8D375DFAC589A222E13AA059319ABF9823B552"

get_datastore() {
  DATA_STORES_RESPONSE=$(make_api_request -s -X GET "${PF_API_HOST}/dataStores/${LDAP_DS_ID}") > /dev/null
}

update_datastore() {
  export PF_LDAP_PASSWORD_OBFUSCATED=$(sh ${SERVER_ROOT_DIR}/bin/obfuscate.sh "${PF_LDAP_PASSWORD}" | tr -d '\n')

  wait_for_admin_api_endpoint

  # Inject obfuscated password into ldap properties file.
  vars='${PF_PD_BIND_USESSL}
${PD_CLUSTER_PRIVATE_HOSTNAME}
${PF_PD_BIND_PORT}'

  LDAP_DS_PAYLOAD=$(envsubst "${vars}" < "${TEMPLATES_DIR_PATH}/pd-ldap-ds.json")

  if get_datastore; then
    make_api_request -X PUT -d "${LDAP_DS_PAYLOAD}" \
      "${PF_API_HOST}/dataStores" > /dev/null
    test $? -ne 0 && return 1
  else
    make_api_request -X POST -d "${LDAP_DS_PAYLOAD}" \
      "${PF_API_HOST}/dataStores" > /dev/null
    test $? -ne 0 && return 1
  fi

}

if ! get_datastore; then
  beluga_log "PD LDAP Data Store isn't there. Adding it."
  update_datastore
else
  beluga_log "PD LDAP Data Store exists, Updating with current password."
  update_datastore
fi

