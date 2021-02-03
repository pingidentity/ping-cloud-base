#!/bin/bash

# Source support libs referenced by the tested script
. "${HOOKS_DIR}"/utils.lib.sh

# Source the script we're testing
script_to_test="${HOOKS_DIR}"/util/upload-csd-s3-utils.sh
. "${script_to_test}"


testTransformPingAccessRuntimeFilename() {
  expected="202101252015-pingaccess-1-support-data.zip"
  filename=$(transform_csd_filename "support-data-ping-pingaccess-1-20210125201530")
  assertEquals "Expected the file name to be ${expected} but it was: $filename" ${expected} ${filename}
}

testTransformPingAccessRuntimeFilenameFailed() {
  filename=$(transform_csd_filename "support-data-pingaccess-1-202101252015")
  assertEquals "Expected the file name to be empty but it was: ${filename}" "" "${filename}"
}

testTransformPingAccessAdminFilenameHappyPath() {
  expected="202101252015-pingaccess-admin-0-support-data.zip"
  filename=$(transform_csd_filename "support-data-ping-pingaccess-admin-0-20210125201530")
  assertEquals "Expected the file name to be ${expected} but it was: $filename" ${expected} ${filename}
}

testTransformPingAccessAdminFilenameFailed() {
  filename=$(transform_csd_filename "support-data-pingaccess-admin-0-202101252015")
  assertEquals "Expected the file name to be empty but it was: ${filename}" "" "${filename}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}