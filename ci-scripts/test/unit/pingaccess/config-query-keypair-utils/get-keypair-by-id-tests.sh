#!/bin/bash

# Source the script we're testing
script_to_test="${PROJECT_DIR}"/profiles/aws/pingaccess/hooks/util/config-query-keypair-utils.sh
. "${script_to_test}"

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/pingaccess/config-query-keypair-utils/resources

# mock the api call
make_api_request() {
    keypairs_response=$(cat "${resources_dir}"/keypairs-items.json)
    echo "${keypairs_response}"
}

testGetKeypairByIdHappyPath() {
    keypair=$(get_keypair_by_id 5)
    alias=$(jq -n "${keypair}" | jq -r .alias)
    assertEquals "The alias should be 'pingaccess-config-query' from this json: ${keypair}" "pingaccess-config-query" "${alias}"
}

# load shunit
. ${SHUNIT_PATH}