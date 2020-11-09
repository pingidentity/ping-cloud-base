#!/bin/bash

# Source the script we're testing
script_to_test="${PROJECT_DIR}"/profiles/aws/pingaccess/hooks/util/config-query-keypair-utils.sh
. "${script_to_test}"

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