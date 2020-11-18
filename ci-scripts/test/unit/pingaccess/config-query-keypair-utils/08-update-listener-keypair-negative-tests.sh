#!/bin/bash

# Source support libs referenced by the tested script
. "${PROJECT_DIR}"/profiles/aws/pingaccess/hooks/utils.lib.sh

# Source the script we're testing
script_to_test="${PROJECT_DIR}"/profiles/aws/pingaccess/hooks/util/config-query-keypair-utils.sh
. "${script_to_test}"

templates_dir_path="${PROJECT_DIR}"/profiles/aws/pingaccess/templates/81

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