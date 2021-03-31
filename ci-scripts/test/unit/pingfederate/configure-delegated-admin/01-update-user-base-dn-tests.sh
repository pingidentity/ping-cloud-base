#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

testSadPathUserBaseDnChangeFailure() {

  # Mock up make_api_request as a failure.
  # When calling change_pcv_search_base function, its
  # expected to fail when make_api_request fails to change the search base_dn for the PCV.
  make_api_request() {
    return 1
  }

  change_pcv_search_base > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathUserBaseDnChange() {

  # Mock up make_api_request as a success for creating changing search base_dn.
  make_api_request() {
    return 0
  }

  change_pcv_search_base > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}
