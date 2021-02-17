#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/upload-csd-s3-utils.sh > /dev/null

kubectl() {
  echo ""
}

cd() {
  echo ""
}

find() {
  echo "support-data-ping-pingfederate-1-20210125201530.zip"
}

skbn() {
  echo ""
}

collect-data() {
  echo ""
}

rm() {
  return 1
}

stat() {
  # mock a file size greater than 0
  echo 1
}

oneTimeSetUp() {
  export VERBOSE=false
}

oneTimeTearDown() {
  unset VERBOSE
}

testUploadPingFederateCsdFileRemovalErrors() {

  script_to_test="${HOOKS_DIR}"/82-upload-csd-s3.sh
  result=$(. "${script_to_test}")

  assertEquals "Expected an exit code of 1 but the script returned with a different code with a result of:  $result" 1 $?

  last_line=$(echo "${result}" | tail -1)
  expected_log_msg="Remove exiting with: 1"
  assertContains "Expected '$expected_log_msg' to be in the last line in the output but it wasn't: ${last_line}" "${last_line}" "${expected_log_msg}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
