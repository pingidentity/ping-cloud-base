#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. "${SCRIPT_HOME}"/../../common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# FIXME: re-add httpbin test when server profile is fixed
testUrlsExpect2xx "${PINGACCESS_CONSOLE}" "${PINGACCESS_API}/version" "${PINGACCESS_SWAGGER}"
exit_code1=$?

testUrls "${PINGACCESS_AGENT}" #"${PINGACCESS_RUNTIME}"/anything \
exit_code2=$?

if test "${exit_code1}" -ne 0 || test "${exit_code2}" -ne 0; then
  exit 1
fi

exit 0