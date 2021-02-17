#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/add-engine-utils.sh > /dev/null

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/pingaccess/add-engine-utils/resources

make_api_request() {
  version=$(cat "${resources_dir}"/version.json)
  echo "${version}"
}

testGetVersion() {
  version=$(get_admin_version)
  assertEquals "get_admin_version returned: ${version}" 0 ${?}
  assertEquals "6.1.3.0" "${version}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
