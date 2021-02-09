#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/util/config-query-keypair-utils.sh > /dev/null

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/pingaccess/config-query-keypair-utils/resources

# mock the api call
make_api_request() {
    exit 1
}

testGetConfigQueryListenerIdMakeApiRequestExit1() {
    id=$(get_config_query_listener_id)
    assertEquals "Given the mocked make_api_request function, this should return 1" 1 $?
}

# load shunit
. ${SHUNIT_PATH}