#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/configure-delegated-admin-utils.sh > /dev/null

# Mock up get_idp_adapter_html_form, 404 will cause code to create new idp adapter HTML form.
get_idp_adapter_html_form() {
  export DA_IDP_ADAPTER_HTML_FORM_RESPONSE="HTTP status code: 404"
}

testSadPathCreateIdp() {

  # Mock up make_api_request as a failure.
  # When calling set_idp_adapter_html_form function, its
  # expected to fail when make_api_request fails to create idp adapter HTML form.
  make_api_request() {
    return 1
  }

  set_idp_adapter_html_form > /dev/null 2>&1
  exit_code=$?

  assertEquals 1 ${exit_code}
}

testHappyPathCreateIdp() {

  # Mock up make_api_request as a success for creating idp adapter HTML form.
  make_api_request() {
    return 0
  }

  set_idp_adapter_html_form > /dev/null 2>&1
  exit_code=$?

  assertEquals 0 ${exit_code}
}

# load shunit
. ${SHUNIT_PATH}
