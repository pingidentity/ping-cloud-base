#!/usr/bin/env sh

function generate_keypair() {
    local templates_dir_path=${1:-"undefined"}

    if [ ${templates_dir_path} = "undefined" ]; then
        beluga_log "templates_dir_path is required but was not passed in as a parameter"
        return 1
    fi

    local config_query_keypair_payload=$(envsubst < ${templates_dir_path})
    create_config_query_keypair_response=$(make_api_request -s -d \
        "${config_query_keypair_payload}" \
        "https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/keyPairs/generate")
    test $? -ne 0 && return 1

    local keypair_id_response=$(jq -n "${create_config_query_keypair_response}" | jq '.id')
    echo ${keypair_id_response}
}

function get_config_query_listener_id() {
    https_listeners_response=$(make_api_request -s "https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/httpsListeners")
    test $? -ne 0 && return 1

    config_query_listener_id=$(jq -n "${https_listeners_response}" | jq '.items[] | select(.name=="CONFIG QUERY") | .id')
    echo ${config_query_listener_id}
}

function update_listener_keypair() {
    local keypair_id=${1:-"undefined"}
    local config_query_listener_id=${2:-"undefined"}
    local templates_dir_path=${3:-"undefined"}

    if [ ${keypair_id} = "undefined" ]; then
        beluga_log "keypair_id is required but was not passed in as a parameter"
        return 1
    fi

    if [ ${config_query_listener_id} = "undefined" ]; then
        beluga_log "config_query_listener_id is required but was not passed in as a parameter"
        return 1
    fi

    if [ ${templates_dir_path} = "undefined" ]; then
        beluga_log "templates_dir_path is required but was not passed in as a parameter"
        return 1
    fi

    # Update CONFIG QUERY HTTPS Listener with with the new keypair
    beluga_log "Updating the Config Query HTTPS Listener ${config_query_listener_id} with the new KeyPair id: ${keypair_id}"

    # Export CONFIG_QUERY_KEYPAIR_ID so it will get injected into
    # config-query.json.
    export CONFIG_QUERY_KEYPAIR_ID=${keypair_id}
    local config_query_payload=$(envsubst < ${templates_dir_path})
    unset CONFIG_QUERY_KEYPAIR_ID

    make_api_request -s -X PUT \
        -d "${config_query_payload}" \
        "https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/httpsListeners/${config_query_listener_id}"
}

function get_config_query_keypair() {
    get_config_query_keypair_response=$(make_api_request -s "https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/keyPairs")
    test $? -ne 0 && return 1

    local config_query_keypair=$(jq -n "${get_config_query_keypair_response}" \
        | jq --arg cq_kp_alias "${CONFIG_QUERY_KP_ALIAS}" '.items[] | select(.alias == $cq_kp_alias)')
    echo ${config_query_keypair}
}

function keypair_has_san() {
    local config_query_keypair_response="${1}"
    local subject_alt_names=$(jq -n "${config_query_keypair_response}" | jq .subjectAlternativeNames)

    if test "${subject_alt_names}" = "null"; then
        echo "false"
        return 0
    fi

    echo "true"
}

function get_config_query_keypair_id() {
    local https_listeners_response=$(make_api_request https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/httpsListeners)
    local config_query_listener_keypair_id=$(jq -n "${https_listeners_response}" \
        | jq '.items[] | select(.name=="CONFIG QUERY") | .keyPairId')
    echo ${config_query_listener_keypair_id}
}

function get_keypair_by_id() {
    local id=${1:="undefined"}

    if [ ${id} = "undefined" ]; then
        beluga_log "id is required but was not passed in as a parameter"
        return 1
    fi

    get_config_query_keypair_response=$(make_api_request https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/keyPairs)
    test $? -ne 0 && return 1

    local keypair_response=$(jq -n "${get_config_query_keypair_response}" \
            | jq -r '.items[] | select(.id=='${id}')')
    echo ${keypair_response}
}

function upgrade_config_query_listener_keypair() {
    local templates_dir_path=${1:-"undefined"}

    if [ ${templates_dir_path} = "undefined" ]; then
        beluga_log "templates_dir_path is required but was not passed in as a parameter"
        exit 1
    fi

    beluga_log "Upgrade the Config Query Keypair if necessary..."
    beluga_log "Get the Keypair on the Config Query HTTPS Listener..."

    # Fetch the keyPairId associated with the Config Query
    # HTTPSListener
    local config_query_keypair_id_response=$(get_config_query_keypair_id)

    # Get the keypair using the keyPairId
    local keypair_response=$(get_keypair_by_id ${config_query_keypair_id_response})

    # Extract the alias
    local keypair_alias=$(jq -n "${keypair_response}" | jq -r .alias)

    # PDO-1385 - Do not proceed with the upgrade if the keypair doesn't have the
    # v1.5 configured alias 'pingaccess-config-query'.  This protects a keypair an
    # admin might have configured after initial setup as well as previous successful
    # upgrades to a keypair with a SAN.
    if [ 'pingaccess-config-query' != "${keypair_alias}" ]; then
        beluga_log "The Keypair on the Config Query HTTPS Listener does not match the default.  Skipping the Config Query Keypair upgrade."
        return 0
    fi

    # PDO-1385 - Replace the Config Query Keypair with one that has a SAN.
    keypair_has_san=$(keypair_has_san "${keypair_response}")
    test $? -ne 0 && return 1

    if [ "${keypair_has_san}" = 'false' ]; then
        beluga_log "The current Config Query Keypair does not have a Subject Alt Name.  Replacing it with one that does..."

        # Export CONFIG_QUERY_KP_ALIAS and CONFIG_QUERY_KP_VALID_DAYS
        # so they will get injected into config-query-keypair.json.
        export CONFIG_QUERY_KP_ALIAS='pingaccess-config-query-with-san'
        export CONFIG_QUERY_KP_VALID_DAYS=${CONFIG_QUERY_KP_VALID_DAYS:-365}

        # Generate a new keypair for the config query listener
        beluga_log "Creating a new keypair using a Subject Alt Name..."
        keypair_id=$(generate_keypair "${templates_dir_path}/config-query-keypair.json")
        test $? -ne 0 && return 1

        beluga_log "New keypair successfully created with the id: ${keypair_id}"

        # Update the Config Query HTTPS Listener with the new keypair id
        config_query_listener_id=$(get_config_query_listener_id)
        test $? -ne 0 && return 1

        update_listener_keypair ${keypair_id} ${config_query_listener_id} "${templates_dir_path}/config-query.json"
        test $? -ne 0 && return 1

        # Clean up the global variables
        unset CONFIG_QUERY_KP_VALID_DAYS
        unset CONFIG_QUERY_KEYPAIR_ID

        beluga_log "Successfully upgraded the Config Query HTTPS Listener to use a Keypair with a Subject Alt Name."
    else
        beluga_log "The current Config Query Keypair has a Subject Alt Name.  There's no need to replace it."
    fi
}
