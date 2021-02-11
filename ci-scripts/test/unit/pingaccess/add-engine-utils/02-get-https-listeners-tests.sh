#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/add-engine-utils.sh > /dev/null

# Reuse the json files from another batch of tests
readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/pingaccess/config-query-keypair-utils/resources

make_api_request() {
  https_listeners_response=$(cat "${resources_dir}"/https-listeners-items.json)
  echo "${https_listeners_response}"
}

testGetHttpsListeners() {
  https_listeners=$(get_https_listeners)
  assertEquals "get_https_listeners returned: ${https_listeners}" 0 ${?}
  assertContains "The mocked json response is not valid.  Did the resource file move?" "${https_listeners}" "ADMIN"
  assertContains "The mocked json response is not valid.  Did the resource file move?" "${https_listeners}" "ENGINE"
  assertContains "The mocked json response is not valid.  Did the resource file move?" "${https_listeners}" "AGENT"
  assertContains "The mocked json response is not valid.  Did the resource file move?" "${https_listeners}" "CONFIG QUERY"

  key_pair_id=$(get_key_pair_id "${https_listeners}")
  assertEquals "get_config_query_key_pair_id returned: ${key_pair_id}" 0 ${?}
  assertEquals "The CONFIG QUERY key pair id should be 6 from the mocked file.  Did the resource file change?" 6 ${key_pair_id}
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
