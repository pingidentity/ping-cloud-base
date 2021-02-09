#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/upload-csd-s3-utils.sh > /dev/null

# Mock up the curl responses
# when it's called from the
# make_api_request function.
curl() {
  # get the last arg
  # in the list
  arg=${@: -1}

  local curl_result http_status
  case "${arg}" in
    'ok')
      http_status=200
      curl_result=0
      ;;
    'unauthorized')
      http_status=401
      curl_result=0
      ;;
    'conn_error')
      curl_result=1
  esac

  echo "${http_status}"
  return "${curl_result}"
}

cat() {
  return 0
}

rm() {
  return 0
}

oneTimeSetUp() {
  export VERBOSE=false
}

oneTimeTearDown() {
  unset VERBOSE
}

##### Begin Tests: Make API requests and expect JSON response #####
testMakeApiRequestOk() {
  make_api_request 'ok'
  exit_code=$?

  assertEquals 0 ${exit_code}
}

testMakeApiRequestUnauthorized() {
  msg=$(make_api_request 'unauthorized')
  exit_code=$?

  assertEquals 1 ${exit_code}
  assertContains "${msg}" 'API call returned HTTP status code: 401'
}

testMakeApiRequestConnError() {
  msg=$(make_api_request 'conn_error')
  exit_code=$?

  # The returned status code here is 127 despite
  # returned status code 1 in the function.  Bug?
  assertEquals 1 ${exit_code}
  assertContains "${msg}" 'Admin API connection refused'
}
##### End Tests: Make API requests and expect JSON response #####


##### Begin Tests: Make API Requests and expect file download #####
testMakeApiRequestDownloadOk() {
  make_api_request_download 'ok'
  exit_code=$?

  assertEquals 0 ${exit_code}
}

testMakeApiRequestDownloadUnauthorized() {
  msg=$(make_api_request_download 'unauthorized')
  exit_code=$?

  assertEquals 1 ${exit_code}
  assertContains "${msg}" 'API call returned HTTP status code: 401'
}

testMakeApiRequestDownloadConnError() {
  msg=$(make_api_request_download 'conn_error')
  exit_code=$?

  # The returned status code here is 127 despite
  # returned status code 1 in the function.  Bug?
  assertEquals 1 ${exit_code}
  assertContains "${msg}" 'Admin API connection refused'
}
##### End Tests: Make API Requests and expect file download #####

# load shunit
. ${SHUNIT_PATH}
