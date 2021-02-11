#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/add-engine-utils.sh > /dev/null

readonly resources_dir="${PROJECT_DIR}"/ci-scripts/test/unit/pingaccess/add-engine-utils/resources

make_api_request() {
  engines=$(cat "${resources_dir}"/engine-items.json)
  echo "${engines}"
}

testEngines() {
  engines=$(get_engines)
  assertEquals "get_engine_trusted_certs returned: ${engines}" 0 ${?}
  assertContains "The mocked json response is not valid.  Did the resource file move?" "${engines}" "pingaccess-was-0"

#   trusted_cert_id=$(get_engine_trusted_cert_id "${engine_certs}" "pingaccess-config-query")
#   assertEquals "get_engine_trusted_cert_id returned: ${trusted_cert_id}" 0 ${?}
#   assertContains "The mocked json response is not valid.  Did the resource file move?" "${trusted_cert_id}" "5"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
