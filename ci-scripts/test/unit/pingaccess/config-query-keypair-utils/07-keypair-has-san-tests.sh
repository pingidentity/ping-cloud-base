#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/util/config-query-keypair-utils.sh > /dev/null

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/pingaccess/config-query-keypair-utils/resources

testKeypairWithoutSan() {
    keypair_without_san_json=$(cat "${resources_dir}"/keypair-without-san.json)
    keypair_has_san=$(keypair_has_san "${keypair_without_san_json}")
    assertEquals "The resource keypair-without-san.json does not contain a SAN" 'false' "${keypair_has_san}"
}

testKeypairWithSan() {
    keypair_with_san_json=$(cat "${resources_dir}"/keypair-with-san.json)
    keypair_has_san=$(keypair_has_san "${keypair_with_san_json}")
    assertEquals "The resource keypair-with-san.json contains a SAN" 'true' "${keypair_has_san}"
}

# load shunit
. ${SHUNIT_PATH}