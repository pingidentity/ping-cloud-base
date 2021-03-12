#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

# Mock up get_jwt, 404 will cause code to create new JWT.
get_jwt() {
  export DA_JWT_RESPONSE="HTTP status code: 404"
}

testSadPathCreateJwt() {

  # Mock up make_api_request as a failure.
  # When calling set_jwt function, its
  # expected to fail when make_api_request fails to create JWT.
  make_api_request() {
    return 1
  }

  set_jwt > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathCreateJwt() {

  # Mock up make_api_request as a success for creating JWT.
  make_api_request() {
    return 0
  }

  set_jwt > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}
