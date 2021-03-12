#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

# Mock up get_exclusive_scope, 404 will cause code to create new exclusive scope.
get_exclusive_scope() {
  export EXCLUSIVE_SCOPE_RESPONSE="HTTP status code: 404"
}

testSadPathCreateExclusiveScope() {

  # Mock up make_api_request as a failure.
  # When calling set_exclusive_scope function, its
  # expected to fail when make_api_request fails to create exclusive scope.
  make_api_request() {
    return 1
  }

  set_exclusive_scope > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathCreateExclusiveScope() {

  # Mock up make_api_request as a success for creating exclusive scope.
  make_api_request() {
    return 0
  }

  set_exclusive_scope > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}
