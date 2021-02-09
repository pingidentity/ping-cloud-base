#!/bin/bash

# Source support libs referenced by the tested script
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/config-query-keypair-utils.sh > /dev/null

templates_dir_path="${TEMPLATES_DIR}"/81

make_api_request() {
    exit 0
}

testGenerateKeypairHappyPath() {
    response=$(generate_keypair "${templates_dir_path}/config-query.json")
    assertEquals "Given the mocked function in this test file and the input parameters, this test should succeed" 0 $?
}

# load shunit
. ${SHUNIT_PATH}