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
  echo "support-data-ping-pingaccess-1-20210125201530.zip"
}

stat() {
  # mock a file size greater than 0
  echo 1
}

skbn() {
  echo ""
}

rm() {
  echo ""
}

collect-data() {
  echo ""
}

oneTimeSetUp() {
  export VERBOSE=false
}

oneTimeTearDown() {
  unset VERBOSE
}

testUploadPingAccessCsdHappyPath() {

  script_to_test="${HOOKS_DIR}"/82-upload-csd-s3.sh
  result=$(. "${script_to_test}")

  assertEquals "Expected an exit code of 0 but the script returned 1 with a result of:  $result" 0 $?

  # Integration tests rely on the zip file name being printed at the end
  last_line=$(echo "${result}" | tail -1)
  new_filename="202101252015-pingaccess-1-support-data.zip"
  assertEquals "Expected $new_filename to be the last line in the output but it was: ${last_line}" "${new_filename}" "${last_line}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}