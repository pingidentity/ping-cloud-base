#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

get_pcv() {
  export DA_PCV_RESPONSE="HTTP status code: 404"
}

testSadPathCreatePVC() {
  # Mock up make_api_request as a failure.
  # When calling set_pcv function, its
  # expected to fail when make_api_request fails to create PCV.
  make_api_request() {
    return 1
  }

  set_pcv > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathCreatePVC() {
  # Mock up make_api_request as a success for creating PCV.
  make_api_request() {
    return 0
  }

  set_pcv > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}
