#!/bin/bash

# Source support libs referenced by the tested script
. "${PROJECT_DIR}"/profiles/aws/pingfederate/hooks/utils.lib.sh
. "${PROJECT_DIR}"/profiles/aws/pingfederate/hooks/util/upload-csd-s3-utils.sh

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

rm() {
  echo ""
}

collect-data() {
  echo ""
}

oneTimeSetUp() {
  export HOOKS_DIR="${PROJECT_DIR}"/profiles/aws/pingfederate/hooks
  export VERBOSE=false
}

oneTimeTearDown() {
  unset HOOKS_DIR
  unset VERBOSE
}

testUploadPingFederateCsdHappyPath() {

  script_to_test="${PROJECT_DIR}"/profiles/aws/pingfederate/hooks/82-upload-csd-s3.sh
  result=$(. "${script_to_test}")

  assertEquals "Expected an exit code of 0 but the script returned 1 with a result of:  $result" 0 $?

  # Integration tests rely on the zip file name being printed at the end
  last_line=$(echo "${result}" | tail -1)
  new_filename="202101252015-pingfederate-1-support-data.zip"
  assertEquals "Expected $new_filename to be the last line in the output but it was: ${last_line}" "${new_filename}" "${last_line}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}