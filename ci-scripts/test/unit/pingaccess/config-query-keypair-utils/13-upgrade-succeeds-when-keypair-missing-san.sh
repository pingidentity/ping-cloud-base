#!/bin/bash

# Source support libs referenced by the tested script
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/config-query-keypair-utils.sh > /dev/null

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/pingaccess/config-query-keypair-utils/resources

# mock calls to config-query-keypair-utils
get_config_query_keypair_id() {
    echo 5
}

# Return a v1.5 type of keypair that
# PDO-1385 aims to replace
get_keypair_by_id() {
    keypair=$(cat "${resources_dir}"/keypair-without-san.json)
    echo "${keypair}"
}

# Mock the call to generate a new keypair
generate_keypair() {
    echo 5
}

# Mock the call to get the listener id
get_config_query_listener_id() {
    echo 4
}

# Need to mock this call since you can only
# mock make_api_request once.
get_config_query_listener_id() {
    echo 4
}

# mock the api call update the listener keypair
make_api_request() {
    updated_listener=$(cat "${resources_dir}"/updated-https-listener.json)
    echo "${updated_listener}"
}

# Here, test the logic all the way through to when the https listener is
# updated with the new keypair
testUpgradeSucceedsWhenKeypairMissingSan() {
    local templates_dir_path="${TEMPLATES_DIR}"/81
    logs=$(upgrade_config_query_listener_keypair "${templates_dir_path}")

    # Look for the message indicating the upgrade was skipped
    message="Successfully upgraded the Config Query HTTPS Listener to use a Keypair with a Subject Alt Name."
    assertContains "Given the mock functions in this test, the upgrade should have succeeded." "${logs}" "${message}"
}

# load shunit
. ${SHUNIT_PATH}