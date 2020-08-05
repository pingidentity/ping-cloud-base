#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

TEMPLATES_DIR_PATH=${STAGING_DIR}/templates/82

is_previously_configured() {
  local create_tp_settings_response=$(make_api_request "https://localhost:9000/pa-admin-api/v3/tokenProvider/settings")
  local token_provider=$(jq -n "${create_tp_settings_response}" | jq '.type')

  if test "${token_provider}" = '"PingOneForCustomers"'; then
    beluga_log "configure-p14c: p14c already configured, exiting"
    return 0
  else
    return 1
  fi
}

add_p14c_credentials() {
  local p14c_config=$(envsubst < ${TEMPLATES_DIR_PATH}/p14c-config.json)

  beluga_log "configure-p14c: adding p14c credentials"
  beluga_log "configure-p14c: make_api_request response..."
  make_api_request -s -X PUT \
      -d "${p14c_config}" \
      "https://localhost:9000/pa-admin-api/v3/pingone/customers"
}

set_p14c_as_token_provider() {
  local token_provider_config=$(envsubst < ${TEMPLATES_DIR_PATH}/token-provider-config.json)

  beluga_log "configure-p14c: setting p14c as token provider"
  beluga_log "configure-p14c: make_api_request response..."
  make_api_request -s -X PUT \
      -d "${token_provider_config}" \
      "https://localhost:9000/pa-admin-api/v3/tokenProvider/settings"
}

is_previously_configured && exit 0
add_p14c_credentials
set_p14c_as_token_provider

beluga_log "configure-p14c: configuration complete"
