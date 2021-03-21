#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

TEMPLATES_DIR_PATH=${STAGING_DIR}/templates/82
PINGACCESS_ADMIN_API_ENDPOINT="https://localhost:9000/pa-admin-api/v3"

is_previously_configured() {
  local create_tp_settings_response=$(make_api_request "${PINGACCESS_ADMIN_API_ENDPOINT}/tokenProvider/settings")
  test $? -ne 0 && return 1

  local token_provider=$(jq -n "${create_tp_settings_response}" | jq '.type')

  if test "${token_provider}" = '"PingOneForCustomers"'; then
    beluga_log "P14C already configured"
    return 0
  else
    return 1
  fi
}

p14c_credentials_changed() {
  get_p14c_issuer

  if test "${ISSUER}" != "${P14C_ISSUER}"; then
    beluga_log "P14C credentials changed"
    return 0
  else
    beluga_log "P14C credentials unchanged"
    return 1
  fi
}

get_p14c_issuer() {
  ISSUER= # Global scope
  local get_p14c_response=$(make_api_request "${PINGACCESS_ADMIN_API_ENDPOINT}/pingone/customers")
  test $? -ne 0 && return 1

  ISSUER=$(jq -n "${get_p14c_response}" | jq '.issuer')
  ISSUER=$(strip_double_quotes "${ISSUER}")
}

add_p14c_credentials() {
  local p14c_config=$(envsubst < ${TEMPLATES_DIR_PATH}/p14c-config.json)

  beluga_log "Adding p14c credentials"
  beluga_log "make_api_request response..."
  make_api_request -s -X PUT \
      -d "${p14c_config}" \
      "${PINGACCESS_ADMIN_API_ENDPOINT}/pingone/customers"  
  return $?
}

set_p14c_as_token_provider() {
  local token_provider_config=$(envsubst < ${TEMPLATES_DIR_PATH}/token-provider-config.json)

  beluga_log "Setting p14c as token provider"
  beluga_log "make_api_request response..."
  make_api_request -s -X PUT \
      -d "${token_provider_config}" \
      "${PINGACCESS_ADMIN_API_ENDPOINT}/tokenProvider/settings"
  return $?
}

if is_myping_deployment; then
  if is_previously_configured; then
    exit 0
  fi
  export P14C_ISSUER="${AUTH_SERVER_BASE_URL}/${ENVIRONMENT_ID}/as"
else
  if is_previously_configured && ! p14c_credentials_changed; then
    exit 0
  fi
fi

if ! add_p14c_credentials; then
  beluga_error "Failed to add P14C credentials"
  exit 1
fi

if ! set_p14c_as_token_provider; then
  beluga_error "Failed to add P14C as a token provider"
  exit 1
fi

beluga_log "Configuration complete"
