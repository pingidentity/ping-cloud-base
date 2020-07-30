#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testUrls() {

#    testUrlsExpect2xx ${PINGFEDERATE_CONSOLE} ${PINGFEDERATE_API} ${PINGFEDERATE_OAUTH_PLAYGROUND}
    testUrlsExpect2xx ${PINGFEDERATE_API}
    assertEquals 0 ${?}
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}