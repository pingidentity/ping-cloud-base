#!/usr/bin/env sh

PF_API_404_MESSAGE="HTTP status code: 404"
TEMPLATES_DIR_PATH="${STAGING_DIR}"/templates/83
PF_API_HOST="https://${PF_ADMIN_HOST_PORT}/pf-admin-api/v1"

########################################################################################################################
# Retrieve DA password credential validator.
########################################################################################################################
get_pcv() {
  DA_PCV_RESPONSE=$(make_api_request -X GET \
    "${PF_API_HOST}/passwordCredentialValidators/${DA_PCV_ID}") > /dev/null
}

########################################################################################################################
# Create password credential validator for DA if it doesn't exist already.
#
# Template Used:
#   create-password-credentials-validator.json:
#   
#   Variables:
#   ${DA_PCV_ID} -> The name you want to use as the password credential validator.
#   ${PD_DATASTORE_ID} -> The ID for PDs LDAP data store "appintegrations".
#   ${USER_BASE_DN} -> The USER_BASE_DN from PD.
#   ${DA_PCV_SEARCH_FILTER} -> The search filter that is used to log into the DA app.
########################################################################################################################
set_pcv() {
  unset PD_DATASTORE_ID

  get_pcv

  # If API return 404 status code. Proceed to create PCV.
  if test $(echo "${DA_PCV_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

    beluga_log "Creating PCV"

    pcv_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-password-credentials-validator.json)

    beluga_log "Using payload"
    echo
    echo "${pcv_payload}" | jq
    echo

    make_api_request -X POST -d "${pcv_payload}" \
      "${PF_API_HOST}/passwordCredentialValidators" > /dev/null
    response_status_code=$?

    if test ${response_status_code} -ne 0; then
      return ${response_status_code}
    fi

    beluga_log "PCV, '${DA_PCV_ID}', successfully created"
  else
    beluga_log "PCV, '${DA_PCV_ID}', already exist"

    # Look to see if USER_BASE_DN has changed.
    if ! checkUserBaseDn; then
      return 1
    fi

    beluga_log "PCV, ${DA_PCV_ID}, is using search base '${USER_BASE_DN}'"
  fi
}

########################################################################################################################
# Check and see if USER_BASE_DN (search base) has changed. If so, then proceed to call change_pcv_search_base function.
########################################################################################################################
checkUserBaseDn() {
  # Change PCV search base if its different than PD USER_BASE_DN.
  current_pcv_user_base_dn=$(jq -n "${DA_PCV_RESPONSE}" | jq -r '.configuration.fields[] | select(.name=="Search Base") | .value')

  if [[ "${current_pcv_user_base_dn}" != "${USER_BASE_DN}" ]]; then
    if ! change_pcv_search_base; then
      beluga_error "Something went wrong when attempting to change, ${DA_PCV_ID}, search base"
      return 1
    fi
  fi

  return 0
}

########################################################################################################################
# Change the USER_BASE_DN (search base) within password credential validator.
########################################################################################################################
change_pcv_search_base() {
  beluga_log "Changing PCV, ${DA_PCV_ID}, search base. Its current value is '${current_pcv_user_base_dn}' and needs to be the same as PD USER_BASE_DN '${USER_BASE_DN}'"

  new_user_base_dn_payload=$(jq -n "${DA_PCV_RESPONSE}" |\
    jq --arg user_base_dn "${USER_BASE_DN}" '(.configuration.fields[] | select(.name=="Search Base") | .value) |= $user_base_dn')

  beluga_log "Using payload"
  echo
  echo "${new_user_base_dn_payload}" | jq
  echo

  make_api_request -X PUT -d "${new_user_base_dn_payload}" \
    "${PF_API_HOST}/passwordCredentialValidators/${DA_PCV_ID}" > /dev/null
  response_status_code=$?
  
  if test ${response_status_code} -ne 0; then
    return ${response_status_code}
  fi

  beluga_log "PCV, ${DA_PCV_ID}, search base successfully updated to ${USER_BASE_DN}"
}

########################################################################################################################
# Retrieve DA IDP Adapter HTML Form.
########################################################################################################################
get_idp_adapter_html_form() {
  DA_IDP_ADAPTER_HTML_FORM_RESPONSE=$(make_api_request -X GET \
    "${PF_API_HOST}/idp/adapters/${DA_IDP_ADAPTER_HTML_FORM_ID}") > /dev/null
}

########################################################################################################################
# Create IDP Adapter HTML Form for DA if it doesn't exist already.
#
# Template Used:
#   create-idp-adapter-html-form.json:
#   
#   Variables:
#   ${DA_IDP_ADAPTER_HTML_FORM_ID} -> The name you want to use as the IDP Adapter HTML Form.
#   ${DA_PCV_ID} -> DA password credential validator name.
########################################################################################################################
set_idp_adapter_html_form() {

  get_idp_adapter_html_form

  # If API return 404 status code. Proceed to create IDP adapter HTML form.
  if test $(echo "${DA_IDP_ADAPTER_HTML_FORM_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

    beluga_log "Creating IDP adapter html form"

    idp_adapter_html_form_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-idp-adapter-html-form.json)

    beluga_log "Using payload"
    echo
    echo "${idp_adapter_html_form_payload}" | jq
    echo

    make_api_request -X POST -d "${idp_adapter_html_form_payload}" \
      "${PF_API_HOST}/idp/adapters" > /dev/null
    response_status_code=$?
    
    if test ${response_status_code} -ne 0; then
      return ${response_status_code}
    fi

    beluga_log "IDP adapter HTML form, '${DA_IDP_ADAPTER_HTML_FORM_ID}', successfully created"
  else
    beluga_log "IDP adapter HTML form, '${DA_IDP_ADAPTER_HTML_FORM_ID}', already exist"
  fi
}

########################################################################################################################
# Retrieve DA IDP Adapter Mapping.
########################################################################################################################
get_idp_adapter_mapping() {
  DA_IDP_ADAPTER_MAPPING_RESPONSE=$(make_api_request -X GET \
    "${PF_API_HOST}/oauth/idpAdapterMappings/${DA_IDP_ADAPTER_HTML_FORM_ID}") > /dev/null
}

########################################################################################################################
# Create IDP Adapter Mapping for DA if it doesn't exist already.
#
# Template Used:
#   create-idp-adapter-mapping.json:
#   
#   Variables:
#   ${DA_IDP_ADAPTER_HTML_FORM_ID} -> Maps to the existing DA IDP Adapter HTML Form.
########################################################################################################################
set_idp_adapter_mapping() {

  get_idp_adapter_mapping

  # If API return 404 status code. Proceed to create IDP adapter mapping.
  if test $(echo "${DA_IDP_ADAPTER_MAPPING_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

    beluga_log "Creating IDP adapter mapping"

    idp_adapter_mapping_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-idp-adapter-mapping.json)

    beluga_log "Using payload"
    echo
    echo "${idp_adapter_mapping_payload}" | jq
    echo

    make_api_request -X POST -d "${idp_adapter_mapping_payload}" \
      "${PF_API_HOST}/oauth/idpAdapterMappings" > /dev/null
    response_status_code=$?
    
    if test ${response_status_code} -ne 0; then
      return ${response_status_code}
    fi

    beluga_log "IDP adapter mapping, '${DA_IDP_ADAPTER_HTML_FORM_ID}', successfully created"
  else
    beluga_log "IDP adapter mapping, '${DA_IDP_ADAPTER_HTML_FORM_ID}', already exist"
  fi
}

########################################################################################################################
# Retrieve DA JWT.
########################################################################################################################
get_jwt() {
  DA_JWT_RESPONSE=$(make_api_request -X GET \
    "${PF_API_HOST}/oauth/accessTokenManagers/${DA_JWT_ID}") > /dev/null
}

########################################################################################################################
# Create JWT for DA if it doesn't exist already.
#
# Template Used:
#   create-jwt.json:
#   
#   Variables:
#   ${DA_JWT_ID} -> The name you want to use as the JWT.
#   ${DA_JWT_SYMMETRIC_KEY} -> The random generated symmetric key used to encrypt and decrypt JWT.
########################################################################################################################
set_jwt() {
  unset DA_JWT_SYMMETRIC_KEY

  get_jwt

  # If API return 404 status code. Proceed to create JWT.
  if test $(echo "${DA_JWT_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

    beluga_log "Creating JWT"

    # Generate random symmetric key and export. It is required within template create-jwt.
    export DA_JWT_SYMMETRIC_KEY=$(dd if=/dev/urandom count=5 bs=8 | xxd -p | head -n 2 | tr -d '[:space:]')

    create_jwt_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-jwt.json)

    make_api_request -X POST -d "${create_jwt_payload}" \
    "${PF_API_HOST}/oauth/accessTokenManagers" > /dev/null
    response_status_code=$?
    
    if test ${response_status_code} -ne 0; then
      return ${response_status_code}
    fi

    beluga_log "JWT, '${DA_JWT_ID}', successfully created"
  else
    beluga_log "JWT, '${DA_JWT_ID}', already exist"
  fi
}

########################################################################################################################
# Retrieve DA JWT Mapping.
########################################################################################################################
get_jwt_default_mapping() {
  jwt_default_mapping_id="default%7C${DA_JWT_ID}"
  DA_JWT_DEFAULT_MAPPING_RESPONSE=$(make_api_request -X GET \
    "${PF_API_HOST}/oauth/accessTokenMappings/${jwt_default_mapping_id}") > /dev/null
}

########################################################################################################################
# Create JWT Mapping for DA if it doesn't exist already.
#
# Template Used:
#   create-jwt-mapping.json:
#   
#   Variables:
#   ${DA_JWT_ID} -> Maps to the existing DA JWT.
########################################################################################################################
set_jwt_default_mapping() {

  get_jwt_default_mapping

  # If API return 404 status code. Proceed to create JWT default mapping.
  if test $(echo "${DA_JWT_DEFAULT_MAPPING_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

    beluga_log "Creating JWT default mapping"

    jwt_default_mapping_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-jwt-mapping.json)

    beluga_log "Using payload"
    echo
    echo "${jwt_default_mapping_payload}" | jq
    echo

    make_api_request -X POST -d "${jwt_default_mapping_payload}" \
      "${PF_API_HOST}/oauth/accessTokenMappings" > /dev/null
    response_status_code=$?
    
    if test ${response_status_code} -ne 0; then
      return ${response_status_code}
    fi

    beluga_log "JWT default mapping, '${DA_JWT_ID}', successfully created"
  else
    beluga_log "JWT default mapping, '${DA_JWT_ID}', already exist"
  fi
}

########################################################################################################################
# Retrieve DA Open ID Connect Policy.
########################################################################################################################
get_oidc_policy() {
  DA_OIDC_POLICY_RESPONSE=$(make_api_request -X GET \
    "${PF_API_HOST}/oauth/openIdConnect/policies/${DA_OIDC_POLICY_ID}") > /dev/null
}

########################################################################################################################
# Create Open ID Connect Policy for DA if it doesn't exist already.
#
# Template Used:
#   create-open-id-connect-policy.json:
#   
#   ${DA_OIDC_POLICY_ID} -> The name you want to use as the OIDC policy.
#   ${DA_JWT_ID} -> DA JWT name.
########################################################################################################################
set_oidc_policy() {

  get_oidc_policy

  # If API return 404 status code. Proceed to create OIDC policy.
  if test $(echo "${DA_OIDC_POLICY_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

    beluga_log "Creating OIDC policy"

    oidc_policy_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-open-id-connect-policy.json)

    beluga_log "Using payload"
    echo
    echo "${oidc_policy_payload}" | jq
    echo

    make_api_request -X POST -d "${oidc_policy_payload}" \
      "${PF_API_HOST}/oauth/openIdConnect/policies" > /dev/null
    response_status_code=$?
    
    if test ${response_status_code} -ne 0; then
      return ${response_status_code}
    fi

    beluga_log "OIDC policy, '${DA_OIDC_POLICY_ID}', successfully created"
  else
    beluga_log "OIDC policy, '${DA_OIDC_POLICY_ID}', already exist"
  fi
}

########################################################################################################################
# Retrieve DA exclusive scope.
########################################################################################################################
get_exclusive_scope() {
  EXCLUSIVE_SCOPE_RESPONSE=$(make_api_request -X GET \
    "${PF_API_HOST}/oauth/authServerSettings/scopes/exclusiveScopes/${DA_EXCLUSIVE_SCOPE_NAME}") > /dev/null
}

########################################################################################################################
# Create exclusive scope for DA if it doesn't exist already.
#
# Template Used:
#   create-exclusive-scope.json:
#   
#   ${DA_EXCLUSIVE_SCOPE_NAME} -> The access token scope that is set within PD HTTP servlet.
########################################################################################################################
set_exclusive_scope() {

  get_exclusive_scope

  # If API return 404 status code. Proceed to create exclusive scope.
  if test $(echo "${EXCLUSIVE_SCOPE_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

    beluga_log "Creating exclusive scope"

    exclusive_scope_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-exclusive-scope.json)

    beluga_log "Using payload"
    echo
    echo "${exclusive_scope_payload}" | jq
    echo

    make_api_request -X POST -d "${exclusive_scope_payload}" \
      "${PF_API_HOST}/oauth/authServerSettings/scopes/exclusiveScopes" > /dev/null
    response_status_code=$?
    
    if test ${response_status_code} -ne 0; then
      return ${response_status_code}
    fi

    beluga_log "Exclusive scope, '${DA_EXCLUSIVE_SCOPE_NAME}', created successfully"
  else
    beluga_log "Exclusive scope, '${DA_EXCLUSIVE_SCOPE_NAME}', already exist"
  fi
}

########################################################################################################################
# Get all sessions from PF and return true if DA HTML form was found.

#   ${DA_IDP_ADAPTER_HTML_FORM_ID} -> Name of the DA IDP Adapter HTML Form.
########################################################################################################################
get_session() {
  DA_SESSION_RESPONSE=$(make_api_request -X GET \
    "${PF_API_HOST}/session/authenticationSessionPolicies") > /dev/null

  # Search for DAs session ID from response.
  DA_SESSION_ID=$( jq -n "${DA_SESSION_RESPONSE}" |\
                   jq --arg DA_IDP_ADAPTER_HTML_FORM_ID "${DA_IDP_ADAPTER_HTML_FORM_ID}" \
                    '.items[] | select(.authenticationSource.sourceRef.id==$DA_IDP_ADAPTER_HTML_FORM_ID)' |\
                   jq -r ".id" )

  beluga_log "DA sessionId: ${DA_SESSION_ID}"

  test ! -z "${DA_SESSION_ID}"
}

########################################################################################################################
# Create session to keep users logged in within DA application.
#
# Template Used:
#   enable-session.json:
#   
#   ${DA_EXCLUSIVE_SCOPE_NAME} -> The access token scope that is set within PD HTTP servlet.
########################################################################################################################
set_session() {

  if ! get_session; then

    beluga_log "Enabling sessions to keep user logged in within Delegated Admin app"

    session_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/enable-session.json)

    make_api_request -X POST -d "${session_payload}" \
      "${PF_API_HOST}/session/authenticationSessionPolicies" > /dev/null
    response_status_code=$?
    
    if test ${response_status_code} -ne 0; then
      return ${response_status_code}
    fi

    beluga_log "Successfully enabled DA session"
  else
    beluga_log "DA session already exist"
  fi
}

########################################################################################################################
# Enable adapter and revoked session tracking upon logout.
#
# Template Used:
#   track-enabled-and-revoked-sessions.json:
########################################################################################################################
track_enabled_and_revoke_sessions() {
  beluga_log "Enabling the ability to track adapter sessions for logout"
  beluga_log "Enabling the ability to track revoked sessions on logout"

  session_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/track-enabled-and-revoked-sessions.json)

  make_api_request -X PUT -d "${session_payload}" \
    "${PF_API_HOST}/session/settings" > /dev/null
  response_status_code=$?
  
  if test ${response_status_code} -ne 0; then
    return ${response_status_code}
  fi

  beluga_log "Now tracking adapter and revoked sessions upon logout"
}


########################################################################################################################
# Retrieve auth server settings of PF.
########################################################################################################################
get_auth_server_settings() {
  AUTH_SERVER_SETTINGS_RESPONSE=$(make_api_request -X GET \
    "${PF_API_HOST}/oauth/authServerSettings") > /dev/null
}

########################################################################################################################
# Add PingDirectory HTTP and Delegated Admin host names as allowed origins. 

# Before adding, this function must retrieve the auth server settings payload of PingFederate. It will then call the
# function, buildOriginList, which takes the auth server settings payload and append PD and DA host names to the JSON
# allowedOrigins property.
########################################################################################################################
setAllowedOrigins() {

  if ! get_auth_server_settings; then
    beluga_error "Something went wrong when attempting to get auth server settings response"
    return 1
  fi

  # PD HTTP and PingDelegator hosts are the allowed origins. Build a list of the hosts
  # and append it to AUTH_SERVER_SETTINGS_PAYLOAD
  beluga_log "Updating allowed origins"
  AUTH_SERVER_SETTINGS_PAYLOAD="${AUTH_SERVER_SETTINGS_RESPONSE}"
  buildOriginList

  beluga_log "adding the following allowedOrigns"
  echo "${AUTH_SERVER_SETTINGS_PAYLOAD}" | jq -r ".allowedOrigins"

  beluga_log "Using payload"
  echo
  echo "${AUTH_SERVER_SETTINGS_PAYLOAD}" | jq
  echo

  make_api_request -X PUT -d "${AUTH_SERVER_SETTINGS_PAYLOAD}" \
    "${PF_API_HOST}/oauth/authServerSettings" > /dev/null
  response_status_code=$?
  
  if test ${response_status_code} -ne 0; then
    return ${response_status_code}
  fi

  beluga_log "Auth server settings updated successfully"
}

########################################################################################################################
# Validate that the provided file is present, non-empty and has valid JSON.
#
# Arguments:
#   $1 -> The file to validate.
#
# Returns:
#   0 -> If the file is valid; 1 -> otherwise.
########################################################################################################################
is_valid_json_file() {
  local json_file="$1"
  test ! -f "${json_file}" && return 1
  num_keys="$(jq -r '(keys|length)' "${json_file}")"
  test $? -eq 0 && test ! -z "${num_keys}" && test "${num_keys}" -gt 0
}

########################################################################################################################
# Build PD and DA host names and call addOrigin function to generate payload.
#
# Note:
# If in multi-cluster mode use the descriptor file that holds all the region host names and construct the host name for
# PD and DA.
########################################################################################################################
buildOriginList() {

  descriptor_file="${STAGING_DIR}/topology/descriptor.json"

  if is_multi_cluster && ! is_valid_json_file "${descriptor_file}"; then
    beluga_error "In multi-cluster mode, a non-empty descriptor.json describing the PD topology must be provided"
    return 1
  fi

  # if deploying in multi_cluster environment, then use PDs descriptor.json to get the public host names per region.
  if is_multi_cluster; then
    for region in $(jq 'keys[]' "${descriptor_file}"); do
      # Get region hostname from descriptor file.
      region_hostname=$(jq . "${descriptor_file}" | jq .[$region] | jq -r '.hostname')

      # Construct DA hostname.
      da_hostname="${PD_DELEGATOR_PUBLIC_HOSTNAME%%.*}.${region_hostname#*.}"

      # Construct PD HTTP hostname.
      pd_http_hostname="${PD_HTTP_PUBLIC_HOSTNAME%%.*}.${region_hostname#*.}"

      # Add PD and DA hostname to allowed origin settings.
      for url in "https://${da_hostname}" "https://${pd_http_hostname}"; do
        addOrigin "${url}"
      done
    done
  else
    # Add PD and DA hostname to allowed origin settings.
    for url in "https://${PD_DELEGATOR_PUBLIC_HOSTNAME}" "https://${PD_HTTP_PUBLIC_HOSTNAME}"; do
      addOrigin "${url}"
    done
  fi
}

########################################################################################################################
# Append PD and DA host name to the JSON allowedOrigins property if it doesn't exist already.
#
# Arguments
#   $1 -> The desired url to add as an origin.
########################################################################################################################
addOrigin() {
  url="$1"

  # If url does NOT exist within payload, then add it to .allowedOrigins JSON property.
  # This means only add new urls as allowed origin.
  host_name_already_exist=$(jq -n "${AUTH_SERVER_SETTINGS_PAYLOAD}" | jq --arg url "${url}" '.allowedOrigins | contains([$url])')
  if [[ "${host_name_already_exist}" == "false" ]]; then
    AUTH_SERVER_SETTINGS_PAYLOAD=$(jq -n "${AUTH_SERVER_SETTINGS_PAYLOAD}" | jq --arg url "${url}" '.allowedOrigins |= .+ [$url]')
  fi
}

########################################################################################################################
# Retrieve DA implicit client.
########################################################################################################################
get_implicit_grant_type_client() {
  DA_IMPLICIT_CLIENT_RESPONSE=$(make_api_request -X GET \
    "${PF_API_HOST}/oauth/clients/${DA_IMPLICIT_GRANT_TYPE_CLIENT_ID}") > /dev/null
}


########################################################################################################################
# Create implicit client for DA if it doesn't exist already. Implicit client will also use DA as the callback
# which it calls the function, buildRedirectUriList, to list of all possible DA callbacks.
#
# Template Used:
#   create-implicit-grant-type.json:
#
#   ${DA_IMPLICIT_GRANT_TYPE_CLIENT_ID} -> The name you want to use as the implicit client.
#   ${DA_EXCLUSIVE_SCOPE_NAME} -> DA exclusive scope name.
#   ${DA_JWT_ID} -> DA JWT name.
#   ${DA_OIDC_POLICY_ID} -> DA OIDC policy name.
########################################################################################################################
set_implicit_grant_type_client() {

  get_implicit_grant_type_client

  # If API return 404 status code. Proceed to create implicit grant type client.
  if test $(echo "${DA_IMPLICIT_CLIENT_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

    beluga_log "Creating implicit grant type"

    implicit_grant_type_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-implicit-grant-type.json)

    # Build a list of all DA hostname(s) and merge it to redirectUris JSON property.
    REDIRECT_URIS=$(envsubst < ${TEMPLATES_DIR_PATH}/redirect-uris-template.json)
    buildRedirectUriList

    beluga_log "adding the following redirectURIs"
    echo "${REDIRECT_URIS}" | jq -r ".redirectUris"

    # Join API JSON payload with redirectUris list.
    implicit_grant_type_payload=$(echo "${implicit_grant_type_payload}" ${REDIRECT_URIS} | jq -s add)

    beluga_log "Using payload"
    echo
    echo "${implicit_grant_type_payload}" | jq
    echo

    make_api_request -X POST -d "${implicit_grant_type_payload}" \
      "${PF_API_HOST}/oauth/clients" > /dev/null
    response_status_code=$?

    if test ${response_status_code} -ne 0; then
      return ${response_status_code}
    fi

    beluga_log "Implicit grant type, '${DA_IMPLICIT_GRANT_TYPE_CLIENT_ID}', created successfully"
  else
    beluga_log "Implicit grant type, '${DA_IMPLICIT_GRANT_TYPE_CLIENT_ID}', already exist"
  fi

  return 0
}

########################################################################################################################
# Generate a list of all the possible DA callbacks for the implicit client.
#
# Note:
# If in multi-cluster mode use the descriptor file that holds all the region host names and construct the DA callback
# for all the regions.
########################################################################################################################
buildRedirectUriList() {
  descriptor_file="${STAGING_DIR}/topology/descriptor.json"

  if is_multi_cluster && ! is_valid_json_file "${descriptor_file}"; then
    beluga_error "In multi-cluster mode, a non-empty descriptor.json describing the PD topology must be provided"
    return 1
  fi

  # if deploying in multi_cluster environment, then use PDs descriptor.json to get the public host names per region.
  if is_multi_cluster; then
    for region in $(jq 'keys[]' "${descriptor_file}"); do

      # Get region hostname from descriptor file.
      region_hostname=$(jq . "${descriptor_file}" | jq .[$region] | jq -r '.hostname')

      # Construct DA hostname.
      da_hostname="${PD_DELEGATOR_PUBLIC_HOSTNAME%%.*}.${region_hostname#*.}"

      beluga_log "Adding 'https://${da_hostname}:${PD_DELEGATOR_PUBLIC_PORT}/*' and  'https://${da_hostname}/*' as redirect URIs"

      # Append to redirectUris list.
      addRedirectUri "https://${da_hostname}:${PD_DELEGATOR_PUBLIC_PORT}/*"
      addRedirectUri "https://${da_hostname}/*"
    done
  else
    # Append to redirectUris list.
    beluga_log "Adding 'https://${PD_DELEGATOR_PUBLIC_HOSTNAME}:${PD_DELEGATOR_PUBLIC_PORT}/*' and  'https://${PD_DELEGATOR_PUBLIC_HOSTNAME}/*' as redirect URIs"

    addRedirectUri "https://${PD_DELEGATOR_PUBLIC_HOSTNAME}:${PD_DELEGATOR_PUBLIC_PORT}/*"
    addRedirectUri "https://${PD_DELEGATOR_PUBLIC_HOSTNAME}/*"
  fi
}

########################################################################################################################
# Append to url to redirectUris payload.
# Arguments
#   $1 -> The desired url to add as a redirect URI.
########################################################################################################################
addRedirectUri() {
  url="$1"
  REDIRECT_URIS=$(jq -n "${REDIRECT_URIS}" | jq --arg url "${url}" '.redirectUris |= .+ [$url]' )
}


########################################################################################################################
# Retrieve DA oauth token validator client.
########################################################################################################################
get_oauth_token_validator_client() {
  DA_OAUTH_TOKEN_VAL_CLIENT_RESPONSE=$(make_api_request -X GET \
    "${PF_API_HOST}/oauth/clients/${DA_OAUTH_TOKEN_VALIDATOR_CLIENT_ID}") > /dev/null
}

########################################################################################################################
# Create OAuth token validator client for DA if it doesn't exist already. If client already exist, then call the
# function, sync_oauth_token_validator_password, to sync the same password as to what PD is using as the client-secret.
#
# Template Used:
#   create-authorization-server-grant-type:
#
#   ${DA_OAUTH_TOKEN_VALIDATOR_CLIENT_ID} -> The name you want to use as the OAuth token validator client.
#   ${DA_JWT_ID} -> DA JWT name.
#   ${DA_OIDC_POLICY_ID} -> DA OIDC policy name.
########################################################################################################################
set_oauth_token_validator_client() {

  get_oauth_token_validator_client

  # If API return 404 status code. Proceed to create access token validation grant type client.
  if test $(echo "${DA_OAUTH_TOKEN_VAL_CLIENT_RESPONSE}" | grep "${PF_API_404_MESSAGE}" &> /dev/null; echo $?) -eq 0; then

    beluga_log "Creating OAuth token validator client"

    oauth_token_val_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/create-authorization-server-grant-type.json)

    make_api_request -X POST -d "${oauth_token_val_payload}" \
      "${PF_API_HOST}/oauth/clients" > /dev/null
    response_status_code=$?

    if test ${response_status_code} -ne 0; then
      return ${response_status_code}
    fi

    beluga_log "OAuth token validator client, '${DA_OAUTH_TOKEN_VALIDATOR_CLIENT_ID}', created successfully"
  else
    beluga_log "OAuth token validator client, '${DA_OAUTH_TOKEN_VALIDATOR_CLIENT_ID}', already exist"

    # Sync password with PD.
    # This is done just in case someone has modified DA_OAUTH_TOKEN_VALIDATOR_SECRET.
    if ! sync_oauth_token_validator_password; then
      beluga_error "Something went wrong when synchronizing oauth token secret, DA_OAUTH_TOKEN_VALIDATOR_SECRET, with PD"
      return 1
    fi
    beluga_log "OAuth token validator client password synced successfully with PingDirectory"
  fi

  return 0
}

########################################################################################################################
# Wrapper function that will enable or disable the 2 required clients implicit and OAuth ATV) for Delegated Admin.
#
# Arguments
#   $1 -> 'disable' | 'enable' flag used to set the client.
# Variables Used:
#   ${DA_IMPLICIT_GRANT_TYPE_CLIENT_ID} -> The name of the implicit client.
#   ${DA_IMPLICIT_CLIENT_RESPONSE} -> The JSON response generated by the function get_implicit_grant_type_client.
#   ${DA_OAUTH_TOKEN_VALIDATOR_CLIENT_ID} -> The name of the OAuth token validator client.
#   ${DA_OAUTH_TOKEN_VAL_CLIENT_RESPONSE} -> The JSON response generated by the function get_implicit_grant_type_client.
########################################################################################################################
set_client_ability_wrapper() {
  client_status="$1"

  if [ "${client_status}" == "enable" ]; then
    client_enable_flag="true"
  else
    client_enable_flag="false"
  fi

  # Implicit grant type client, (DA  -> PF)
  if get_implicit_grant_type_client; then
    set_client_ability "${DA_IMPLICIT_GRANT_TYPE_CLIENT_ID}" "${DA_IMPLICIT_CLIENT_RESPONSE}" "${client_enable_flag}"
    implicit_client_status=$?

    if test ${implicit_client_status} -ne 0; then
      beluga_error "Failed to ${client_status} implicit grant type client"
      return ${implicit_client_status}
    fi
  fi

  # OAuth token validator client, (PD -> PF)
  if get_oauth_token_validator_client; then
    set_client_ability "${DA_OAUTH_TOKEN_VALIDATOR_CLIENT_ID}" "${DA_OAUTH_TOKEN_VAL_CLIENT_RESPONSE}" "${client_enable_flag}"
    oauth_token_validator_client_status=$?

    if test ${oauth_token_validator_client_status} -ne 0; then
      beluga_error "Failed to ${client_status} OAuth token validator client"
      return ${oauth_token_validator_client_status}
    fi
  fi

  return 0
}

########################################################################################################################
# Disable OAuth client within PingFederate.
#
# Arguments
#   ${1} -> The name of the client you want to disable.
#   ${2} -> The JSON payload that will update the /oauth/clients/:id endpoint.
#   ${3} -> The enable or disable switch for client. ('true' => enable, 'false' => disable)
########################################################################################################################
set_client_ability() {
  client_id="$1"
  client_response_payload="$2"
  client_ability="$3"

  oauth_token_val_payload=$(jq -n "${client_response_payload}" | jq --arg client_ability "${client_ability}" '.enabled = $client_ability' )

  beluga_log "Using payload and setting client enabled property to '${client_ability}'"
  echo "${oauth_token_val_payload}"
  echo
  echo "${oauth_token_val_payload}" | jq
  echo

  make_api_request -X PUT -d "${oauth_token_val_payload}" \
    "${PF_API_HOST}/oauth/clients/${client_id}" > /dev/null
  response_status_code=$?

  if test ${response_status_code} -ne 0; then
    return ${response_status_code}
  fi

  return 0
}

########################################################################################################################
# Set the OAuth token validator client password as to what PD is using as the client-secret.
########################################################################################################################
sync_oauth_token_validator_password() {
  oauth_token_val_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/sync-oauth-token-validator-password.json)
  make_api_request -X PUT -d "${oauth_token_val_payload}" \
    "${PF_API_HOST}/oauth/clients/${DA_OAUTH_TOKEN_VALIDATOR_CLIENT_ID}/clientAuth/clientSecret" > /dev/null
}

########################################################################################################################
# Retrieve all virtual host names.
########################################################################################################################
getVirtualHostNames() {
  DA_VIRTUAL_HOST_RESPONSE=$(make_api_request -X GET \
    "${PF_API_HOST}/virtualHostNames") > /dev/null
}

########################################################################################################################
# For every region excluding primary. Add  Delegated Admin host name as a virtualhost.
#
# Before adding, this function must retrieve the all virtualhost names payload. It will then call the
# function, buildVirtualHostList, which takes the virtualhost payload and append DA host name to the JSON
# virtualHostNames property.
########################################################################################################################
setVirtualHosts() {
  descriptor_file="${STAGING_DIR}/topology/descriptor.json"

  if is_multi_cluster && ! is_valid_json_file "${descriptor_file}"; then
    beluga_error "In multi-cluster mode, a non-empty descriptor.json describing the PD topology must be provided"
    return 1
  fi

  if ! is_multi_cluster; then
    beluga_log "Not in multi cluster mode. Skip configuration of virtual host"
    return 0
  fi

  if ! getVirtualHostNames; then
    beluga_error "Something went wrong when attempting to get virtual host names response"
    return 1
  fi

  beluga_log "Updating virtual hosts"

  # Build a list of all PF hostname(s) that are not within the primary region and append it to DA_VIRTUAL_HOST_PAYLOAD
  # The BaseURL in PF is what the primary region uses. Any other region will need to be a virtual host.
  DA_VIRTUAL_HOST_PAYLOAD="${DA_VIRTUAL_HOST_RESPONSE}"
  buildVirtualHostList

  make_api_request -X PUT -d "${DA_VIRTUAL_HOST_PAYLOAD}" \
    "${PF_API_HOST}/virtualHostNames" > /dev/null
  response_status_code=$?
  
  if test ${response_status_code} -ne 0; then
    return ${response_status_code}
  fi

  beluga_log "Virtual host settings updated successfully"
}

########################################################################################################################
# Generate a list of DA host names per region and add as a virtual host.
#
# Note:
# Primary region host names are not added as a virtual host as this is currently the PF Base URL.
########################################################################################################################
buildVirtualHostList() {
  descriptor_file="${STAGING_DIR}/topology/descriptor.json"

  # if deploying in multi_cluster environment, then use PDs descriptor.json to get the public host names per region.
  for region in $(jq 'keys[]' "${descriptor_file}"); do
    # Get region hostname from descriptor file.
    region_hostname=$(jq . "${descriptor_file}" | jq .[$region] | jq -r '.hostname')

    # Construct PF Engine hostname.
    pf_hostname="${PF_ENGINE_PUBLIC_HOSTNAME%%.*}.${region_hostname#*.}"

    beluga_log "constructed PingFederate hostname: ${pf_hostname}"

    # Only add secondary or more regions as a virtual host.
    # This if condition is skipping primary region which is PF_ENGINE_PUBLIC_HOSTNAME.
    if [[ "${pf_hostname}" != "${PF_ENGINE_PUBLIC_HOSTNAME}" ]]; then
      addVirtualHost "${pf_hostname}"
    fi
  done
}

########################################################################################################################
# Append to url to virtualHostNames payload.
#
# Arguments
#   $1 -> The desired url to add as a virtual host.
########################################################################################################################
addVirtualHost() {
  url="$1"

  # If url does NOT exist within payload, then add it to .virtualHostNames JSON property.
  # This means only add new virtual hosts.
  virtual_host_name_already_exist=$(jq -n "${DA_VIRTUAL_HOST_PAYLOAD}" | \
    jq --arg url "${url}" '.virtualHostNames | contains([$url])')

  if [[ "${virtual_host_name_already_exist}" == "false" ]]; then
    DA_VIRTUAL_HOST_PAYLOAD=$(jq -n "${DA_VIRTUAL_HOST_PAYLOAD}" | \
    jq --arg url "${url}" '.virtualHostNames |= .+ [$url]' )
  fi
}