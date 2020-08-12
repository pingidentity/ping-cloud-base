#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

TEMPLATES_DIR_PATH=${STAGING_DIR}/templates/82

is_previously_configured() {
  local create_tp_settings_response=$(make_api_request "https://localhost:9000/pa-admin-api/v3/tokenProvider/settings")
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
  local get_p14c_response=$(make_api_request "https://localhost:9000/pa-admin-api/v3/pingone/customers")

  ISSUER=$(jq -n "${get_p14c_response}" | jq '.issuer')
  ISSUER=$(strip_double_quotes "${ISSUER}")
}

add_p14c_credentials() {
  local p14c_config=$(envsubst < ${TEMPLATES_DIR_PATH}/p14c-config.json)

  beluga_log "Adding p14c credentials"
  beluga_log "make_api_request response..."
  make_api_request -s -X PUT \
      -d "${p14c_config}" \
      "https://localhost:9000/pa-admin-api/v3/pingone/customers"
}

set_p14c_as_token_provider() {
  local token_provider_config=$(envsubst < ${TEMPLATES_DIR_PATH}/token-provider-config.json)

  beluga_log "Setting p14c as token provider"
  beluga_log "make_api_request response..."
  make_api_request -s -X PUT \
      -d "${token_provider_config}" \
      "https://localhost:9000/pa-admin-api/v3/tokenProvider/settings"
}

if is_previously_configured && ! p14c_credentials_changed; then
  exit 0
fi

add_p14c_credentials
set_p14c_as_token_provider

beluga_log "Configuration complete"
