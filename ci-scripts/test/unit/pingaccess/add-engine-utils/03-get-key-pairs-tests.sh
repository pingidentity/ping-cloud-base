#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/add-engine-utils.sh > /dev/null

# Reuse the json files from another batch of tests
readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/pingaccess/config-query-keypair-utils/resources

make_api_request() {
  key_pairs_response=$(cat "${resources_dir}"/keypairs-items.json)
  echo "${key_pairs_response}"
}

testGetKeyPairs() {
  key_pairs=$(get_key_pairs)
  assertEquals "get_key_pairs returned: ${key_pairs}" 0 ${?}
  assertContains "The mocked json response is not valid.  Did the resource file move?" "${key_pairs}" "pingaccess-config-query"
  assertContains "The mocked json response is not valid.  Did the resource file move?" "${key_pairs}" "Generated: CONFIG QUERY"

  alias=$(get_alias "${key_pairs}" "5")
  assertEquals "get_alias returned: ${alias}" 0 ${?}
  assertEquals "The alias CONFIG QUERY key pair id should be pingaccess-config-query from the mocked file.  Did the resource file change?" "pingaccess-config-query" "${alias}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
