#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

# Mock up is_multi_cluster, this logic sets is_multi_cluster to false.
is_multi_cluster() {
  return 0
}

testSadPathCreateSession() {

  # Mock up get_session as a failure.
  get_session() {
    return 1
  }

  # Mock up make_api_request as a failure.
  # When calling set_session function, its
  # expected to fail when make_api_request fails to create session for DA.
  make_api_request() {
    return 1
  }

  set_session > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathCreateSession() {

  # Mock up get_session as a failure.
  get_session() {
    return 1
  }

  # Mock up make_api_request as a success for creating session for DA.
  make_api_request() {
    return 0
  }

  set_session > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}
