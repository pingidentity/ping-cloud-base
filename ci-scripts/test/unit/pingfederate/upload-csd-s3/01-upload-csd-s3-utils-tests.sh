#!/bin/bash

# Source support libs referenced by the tested script
. "${HOOKS_DIR}"/utils.lib.sh

# Source the script we're testing
script_to_test="${HOOKS_DIR}"/util/upload-csd-s3-utils.sh
. "${script_to_test}"


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