#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testUrls() {
  # FIXME: re-add httpbin test when server profile is fixed
  testUrlsExpect2xx "${PINGACCESS_CONSOLE}" "${PINGACCESS_API}/version" "${PINGACCESS_SWAGGER}"
  assertEquals 0 $?

#  testUrls "${PINGACCESS_AGENT}"  #"${PINGACCESS_RUNTIME}"/anything
#  assertEquals 0 $?
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}