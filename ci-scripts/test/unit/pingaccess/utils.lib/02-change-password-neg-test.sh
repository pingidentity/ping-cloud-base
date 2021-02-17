#!/bin/bash

# Source the script we're testing
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null

# Mock this function to avoid
# a curl networking call and
# to control the exit code.
make_initial_api_request() {
  return 1
}

# Mock this function call to
# avoid testing issues with
# the filesystem.
function inject_template() {
  echo "{
  \"currentPassword\": \"${OLD_PA_ADMIN_USER_PASSWORD}\",
  \"newPassword\": \"${PA_ADMIN_USER_PASSWORD}\"
}"
  return $?;
}

setUp() {
  export VERBOSE=false
  export OLD_PA_ADMIN_USER_PASSWORD='2Access'
  export PA_ADMIN_USER_PASSWORD='2FederateM0re'
}

oneTimeTearDown() {
  unset VERBOSE
  unset OLD_PA_ADMIN_USER_PASSWORD
  unset PA_ADMIN_USER_PASSWORD
}

testChangePasswordNetworkError() {

  msg=$(changePassword)
  exit_code=$?

  assertEquals 1 ${exit_code}
  assertContains "${msg}" 'password change status: 1'
  assertContains "${msg}" 'error changing password'
}

# load shunit
. ${SHUNIT_PATH}
