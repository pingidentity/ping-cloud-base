#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"
. "${HOOKS_DIR}/util/config-query-keypair-utils.sh"

"${VERBOSE}" && set -x

templates_dir_path="${STAGING_DIR}"/templates/81
PINGACCESS_ADMIN_API_ENDPOINT="https://localhost:9000/pa-admin-api/v3"

function configure_config_query_listener() {

    beluga_log "Check to see if the Config Query Keypair already exists..."
    local config_query_keypair=$(get_config_query_keypair)
    local config_query_keypair_alias=$(jq -n "${config_query_keypair}" | jq -r '.alias')

    # Check to see if the keypair already exists.  This can happen if the
    # s3 bucket already has configuration in it and the restore runs
    # before reaching this script.  The s3 bucket should be clean when
    # this runs in production.  Here we're not changing any of the
    # configuration in case developers aren't cleaning their buckets out.
    # In that case, this script shouldn't change an existing config.
    if [ "${config_query_keypair_alias}" = 'null' ]; then
        beluga_log "Config Query Keypair alias was not found"

        # Export CONFIG_QUERY_KP_ALIAS and CONFIG_QUERY_KP_VALID_DAYS
        # so they will get injected into config-query-keypair.json.
        export CONFIG_QUERY_KP_ALIAS='pingaccess-config-query'
        export CONFIG_QUERY_KP_VALID_DAYS=${CONFIG_QUERY_KP_VALID_DAYS:-365}

        beluga_log "Creating a new keypair..."
        local keypair_id=$(generate_keypair "${templates_dir_path}/config-query-keypair.json")
        test $? -ne 0 && return 1

        beluga_log "New keypair successfully created with the id: ${keypair_id}"

        local config_query_listener_id=$(get_config_query_listener_id)
        update_listener_keypair ${keypair_id} ${config_query_listener_id} "${templates_dir_path}/config-query.json"
        test $? -ne 0 && return 1

        # Clean up the global variables
        unset CONFIG_QUERY_KP_ALIAS
        unset CONFIG_QUERY_KP_VALID_DAYS

    else
        beluga_log "Keypair ${CONFIG_QUERY_KP_ALIAS} already exists.  Skipping configuration of the Keypair, the Config Query HTTPS Listener, and the Admin Config."
    fi
}


# Fetch using the -i flag to get the HTTP response
# headers as well
get_admin_user_response=$(curl -k \
     -i \
     --retry ${API_RETRY_LIMIT} \
     --max-time ${API_TIMEOUT_WAIT} \
     --retry-delay 1 \
     --retry-connrefused \
     -u ${PA_ADMIN_USER_USERNAME}:${OLD_PA_ADMIN_USER_PASSWORD} \
     -H "X-Xsrf-Header: PingAccess" "${PINGACCESS_ADMIN_API_ENDPOINT}/users/1")
"${VERBOSE}" && set -x

# Verify connecting to the user endpoint using credentials
# passed in via env variables.  If this fails with a non-200
# HTTP response then skip the configuration import.
http_response_code=$(printf "${get_admin_user_response}" | awk '/HTTP/' | awk '{print $2}')
beluga_log "${http_response_code}"
if [ 200 = ${http_response_code} ]; then

    admin_user_json=$(printf "${get_admin_user_response}" | awk '/firstLogin/' | awk '{print $0}')
    first_login=$(jq -n "${admin_user_json}" | jq '.firstLogin')

    # Only configure PingAccess if this is the first time
    # through.  We shouldn't clobber an existing configuration.
    if [ 'true' = ${first_login} ]; then

        # Accept EULA
        beluga_log "Accepting the EULA..."
        eula_payload=$(envsubst < ${templates_dir_path}/eula.json)
        make_initial_api_request -s -X PUT \
            -d "${eula_payload}" \
            "${PINGACCESS_ADMIN_API_ENDPOINT}/users/1" > /dev/null
        test $? -ne 0 && exit 1

        beluga_log "Changing the default password..."
        beluga_log "Change password debugging output suppressed"

        changePassword

        # Configure the Config Query HttpsListener
        # with a keypair
        configure_config_query_listener
        test $? -ne 0 && return 1

    else
        beluga_log "PingAccess has already been configured.  Exiting without making configuration changes."
    fi

else
     beluga_log "Received a ${http_response_code} when checking the user endpoint.  Exiting without making configuration changes."
fi

exit 0
