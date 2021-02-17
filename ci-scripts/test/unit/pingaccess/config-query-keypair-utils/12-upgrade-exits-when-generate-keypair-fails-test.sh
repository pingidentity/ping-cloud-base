#!/bin/bash

# Source the script we're testing
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
    exit 1
}

# Here, test the logic all the way through to when the https listener is
# updated with the new keypair
testUpgradeExitsWhenGenerateKeypairFails() {
    local templates_dir_path="${TEMPLATES_DIR}"/81
    response=$(upgrade_config_query_listener_keypair "${templates_dir_path}")
    assertEquals "Given the mock generate_keypair in this test, the upgrade should have failed with 1." 1 $?
}

# load shunit
. ${SHUNIT_PATH}