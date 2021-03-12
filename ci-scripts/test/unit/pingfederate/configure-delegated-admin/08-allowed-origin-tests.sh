#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

# Mock up buildOriginList, this logic builds URLs but can be ignored.
buildOriginList() {
  return 0
}

testSadPathAuthServerSettingsFailure() {

  # Mock up get_auth_server_settings as a failure.
  # When calling setAllowedOrigins function, its
  # expected to fail when get_auth_server_settings fails to get current server settings.
  get_auth_server_settings() {
    return 1
  }

  setAllowedOrigins > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testSadPathUpdateAllowedOrigins() {

  # Mock up get_auth_server_settings as a success.
  get_auth_server_settings() {
    return 0
  }

  # Mock up make_api_request as a failure.
  # When calling setAllowedOrigins function, its
  # expected to fail when make_api_request fails to create allowed origins.
  make_api_request() {
    return 1
  }

  setAllowedOrigins > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathUpdateAllowedOrigins() {

  # Mock up get_auth_server_settings as a success.
  get_auth_server_settings() {
    return 0
  }

  # Mock up make_api_request as a success for updating new allowed origins.
  make_api_request() {
    return 0
  }

  setAllowedOrigins > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}
