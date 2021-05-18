#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

# Mock up is_multi_cluster, this logic sets is_multi_cluster to false.
is_multi_cluster() {
  return 0
}

# Mock up is_valid_json_file, this logic passes descriptor.json validation.
is_valid_json_file() {
  return 0
}

testSadPathVirtualHostsFailure() {

  # Mock up getVirtualHostNames as a failure.
  # When calling setVirtualHosts function, its
  # expected to fail when getVirtualHostNames response returns an error.
  getVirtualHostNames() {
    return 1
  }

  setVirtualHosts > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testSadPathCreateVirtualHosts() {

  # Mock up getVirtualHostNames as a success.
  getVirtualHostNames() {
    return 0
  }

  # Mock up make_api_request as a failure.
  # When calling setVirtualHosts function, its
  # expected to fail when make_api_request fails to create new virtual hosts.
  make_api_request() {
    return 1
  }

  setVirtualHosts > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathCreateVirtualHosts() {

  # Mock up getVirtualHostNames as a success.
  getVirtualHostNames() {
    return 0
  }

  # Mock up make_api_request as a success for creating new virtual hosts.
  make_api_request() {
    return 0
  }

  setVirtualHosts > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}
