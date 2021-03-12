#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

# Mock up buildRedirectUriList, this logic builds URLs but can be ignored.
buildRedirectUriList() {
  return 0
}

# Mock up get_implicit_grant_type_client, 404 will cause code to create new implicit client.
get_implicit_grant_type_client() {
  export DA_IMPLICIT_CLIENT_RESPONSE="HTTP status code: 404"
}

testSadPathCreateImplicitClient() {

  # Mock up make_api_request as a failure.
  # When calling set_implicit_grant_type_client function, its
  # expected to fail when make_api_request fails to create implicit client.
  make_api_request() {
    return 1
  }

  set_implicit_grant_type_client > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathCreateImplicitClient() {

  # Mock up make_api_request as a success for creating implicit client.
  make_api_request() {
    return 0
  }

  set_implicit_grant_type_client > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}
