#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/config-query-keypair-utils.sh > /dev/null

templates_dir_path="${TEMPLATES_DIR}"/81

make_api_request() {
    exit 1
}

testUpdateListenerKeypairMakeApiRequestExit1() {
    keypair_id=1
    config_query_listener_id=4
    response=$(update_listener_keypair ${keypair_id} ${config_query_listener_id} "${templates_dir_path}/config-query.json")
    assertEquals "Given the mocked make_api_request function, this should return 1" 1 $?
}

# load shunit
. ${SHUNIT_PATH}