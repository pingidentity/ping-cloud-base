#!/bin/bash

# Source support libs referenced by the tested script
. "${PROJECT_DIR}"/profiles/aws/pingaccess/hooks/utils.lib.sh

# Source the script we're testing
script_to_test="${PROJECT_DIR}"/profiles/aws/pingaccess/hooks/util/config-query-keypair-utils.sh
. "${script_to_test}"

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/pingaccess/config-query-keypair-utils/resources

# mock calls to config-query-keypair-utils
get_config_query_keypair_id() {
    echo 5
}

# Return a keypair that's already been upgraded
get_keypair_by_id() {
    keypair=$(cat "${resources_dir}"/keypair-with-san.json)
    echo "${keypair}"
}

testUpgradeExitsWhenCurrentKeypairHasSan() {
    local templates_dir_path="${PROJECT_DIR}"/profiles/aws/pingaccess/templates/81
    logs=$(upgrade_config_query_listener_keypair "${templates_dir_path}")
    assertEquals "The function upgrade_config_query_listener_keypair should have exited with a 0." 0 $?

    # Look for the message indicating the upgrade was skipped
    message="The current Config Query Keypair has a Subject Alt Name.  There's no need to replace it."
    assertContains "Given the mock functions in this test, the keypair should have a SAN and should have triggered an exit before the upgrade." "${logs}" "${message}"
}

# load shunit
. ${SHUNIT_PATH}
