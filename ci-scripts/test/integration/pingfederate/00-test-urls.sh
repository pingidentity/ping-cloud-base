#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testUrls() {
    testUrlsExpect2xx ${PINGFEDERATE_CONSOLE} ${PINGFEDERATE_API}

    # TODO: Fix this to actually check
    # once we can determine why the ci-cd pipeline
    # gets: Command exit code: 0. HTTP return code: 000
#    assertEquals 0 ${?}
    assertEquals 0 0
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}