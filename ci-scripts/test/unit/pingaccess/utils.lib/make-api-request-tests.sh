#!/bin/bash

# Source the script we're testing
script_to_test="${PROJECT_DIR}"/profiles/aws/pingaccess/hooks/utils.lib.sh
. "${script_to_test}"

# Mock up the curl responses
# when it's called from the
# make_api_request function.
curl() {
  set +x

  # get the last arg
  # in the list
  arg=${@: -1}

  case "${arg}" in
  'ok')
    echo 200
    return 0
    ;;
  'unauthorized')
    echo 401
    return 0
    ;;
  'conn_error')
    return 1
  esac
}

oneTimeSetUp() {
  export VERBOSE=false
  export STOP_SERVER_ON_FAILURE=false
}

oneTimeTearDown() {
  unset VERBOSE
  unset STOP_SERVER_ON_FAILURE
}

testMakeApiRequestDownloadOk() {
  make_api_request_download 'ok'
  exit_code=$?

  assertEquals 0 ${exit_code}
}

testMakeApiRequestDownloadUnauthorized() {
  set +x
  # Execute in a subshell since this
  # case will exit 1 (rather than return 1)
  msg=$(make_api_request_download 'unauthorized')
  exit_code=$?

  assertEquals 1 ${exit_code}
  assertEquals 'API call returned HTTP status code: 401' "${msg}"
}

testMakeApiRequestDownloadConnError() {

  # Execute in a subshell since this
  # case will exit 1 (rather than return 1)
  msg=$(make_api_request_download 'conn_error')
  exit_code=$?

  # The exit code here is 127 despite
  # exit 1 in the function.  Bug?
  assertEquals 1 ${exit_code}
  assertEquals 'Admin API connection refused' "${msg}"
}

# load shunit
. ${SHUNIT_PATH}
