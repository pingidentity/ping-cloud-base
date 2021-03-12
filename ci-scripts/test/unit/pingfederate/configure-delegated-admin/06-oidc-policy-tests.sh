#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

# Mock up get_oidc_policy, 404 will cause code to create new OIDC policy.
get_oidc_policy() {
  export DA_OIDC_POLICY_RESPONSE="HTTP status code: 404"
}

testSadPathCreateOidcPolicy() {

  # Mock up make_api_request as a failure.
  # When calling set_oidc_policy function, its
  # expected to fail when make_api_request fails to create OIDC policy.
  make_api_request() {
    return 1
  }

  set_oidc_policy > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathCreateOidcPolicy() {

  # Mock up make_api_request as a success for creating OIDC policy.
  make_api_request() {
    return 0
  }

  set_oidc_policy > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}
