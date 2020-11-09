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

testGenerateKeypairMissingParameters() {
    response=$(generate_keypair)
    assertEquals "Without the required parameters passed in, this function should return 1" 1 $?
    message="templates_dir_path is required but was not passed in as a parameter"
    assertContains "Without the required parameters passed in, this function should print an error message" "${response}" "${message}"
}

testGenerateKeypairTestMakeApiRequestExit1() {
    response=$(generate_keypair "${templates_dir_path}/config-query.json")
    assertEquals "Given the mocked function here, this test should return 1" 1 $?
}

# load shunit
. ${SHUNIT_PATH}