#!/bin/bash

# Source support libs referenced by the tested script
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
  echo "support-data-ds-8.1.0.1-pingdirectory-0-20200903203030Z-zip"
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

testUploadPingDirectoryCsdHappyPath() {

  script_to_test="${HOOKS_DIR}"/82-upload-csd-s3.sh
  result=$(. "${script_to_test}")

  assertEquals "Expected an exit code of 0 but the script returned 1 with a result of:  $result" 0 $?

  # Integration tests rely on the zip file name being printed at the end
  last_line=$(echo "${result}" | tail -1)
  new_filename="202009032030-pingdirectory-0-support-data.zip"
  assertEquals "Expected $new_filename to be the last line in the output but it was: ${last_line}" "${new_filename}" "${last_line}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}