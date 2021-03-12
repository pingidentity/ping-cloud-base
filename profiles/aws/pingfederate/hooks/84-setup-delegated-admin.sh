#!/usr/bin/env sh
set -e

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"
. "${HOOKS_DIR}/util/configure-delegated-admin-utils.sh"

# Do not proceed to configure DA if SKIP_DA_SETUP is set to true
if $(echo "${SKIP_DA_SETUP}" | grep -iq "true"); then
  beluga_log "SKIP_DA_SETUP is true, skipping..."
  exit 0
fi

if ! set_pcv; then
  beluga_error "Failed to create PCV"
  exit 1
fi

if ! set_idp_adapter_html_form; then
  beluga_error "Failed to create IDP Adapter HTML Form"
  exit 1
fi

if ! set_idp_adapter_mapping; then
  beluga_error "Failed to create IDP Adapter Mapping"
  exit 1
fi

if ! set_jwt; then
  beluga_error "Failed to create JWT"
  exit 1
fi

if ! set_jwt_default_mapping; then
  beluga_error "Failed to create JWT Mapping"
  exit 1
fi

if ! set_oidc_policy; then
  beluga_error "Failed to create OpenId Connect Policy"
  exit 1
fi

if ! set_exclusive_scope; then
  beluga_error "Failed to create Exclusive Scope"
  exit 1
fi

if ! setAllowedOrigins; then
  beluga_error "Failed to create Allowed Origins"
  exit 1
fi

if ! set_implicit_grant_type_client; then
  beluga_error "Failed to create Implicit Grant Type Client"
  exit 1
fi

if ! set_oauth_token_validator_client; then
  beluga_error "Failed to create OAuth Token Validator Client"
  exit 1
fi

if ! setVirtualHosts; then
  beluga_error "Failed to create Virtual Hosts"
  exit 1
fi