#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/upload-csd-s3-utils.sh > /dev/null

testTransformPingFederateRuntimeFilename() {
  filename=$(transform_csd_filename "support-data-ping-pingfederate-1-20210125201530")
  assertEquals "202101252015-pingfederate-1-support-data.zip" ${filename}
}

testTransformPingFederateRuntimeFilenameFailed() {
  filename=$(transform_csd_filename "support-data-pingfederate-1-202101252015")
  assertEquals "" "${filename}"
}

testTransformPingFederateAdminFilenameHappyPath() {
  filename=$(transform_csd_filename "support-data-ping-pingfederate-admin-0-20210125201530")
  assertEquals "202101252015-pingfederate-admin-0-support-data.zip" ${filename}
}

testTransformPingFederateAdminFilenameFailed() {
  filename=$(transform_csd_filename "support-data-pingfederate-admin-0-202101252015")
  assertEquals "" "${filename}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}