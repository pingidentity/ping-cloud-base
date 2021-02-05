#!/bin/bash

# Source support libs referenced by the tested script
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/upload-csd-s3-utils.sh > /dev/null

testTransformPingDirectoryRuntimeFilename() {
  filename=$(transform_csd_filename "support-data-ds-8.1.0.1-pingdirectory-0-20200903203030Z-zip")
  assertEquals "202009032030-pingdirectory-0-support-data.zip" ${filename}
}

testTransformPingDirectoryRuntimeFilenameFailed() {
  filename=$(transform_csd_filename "support-data-8.1.0.1-pingdirectory-0-20200903203030Z-zip")
  assertEquals "" "${filename}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}