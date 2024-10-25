#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}/common.sh" "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testNGINXVersionMatch() {
  export nginx_expected_version="1.11.2"
  # Use UBER_YAML outputted by compile stage to check version of ingress-nginx
  yq -e 'select(.metadata.labels."app.kubernetes.io/name" == "ingress-nginx") | select(.metadata.labels."app.kubernetes.io/version" != env(nginx_expected_version))' "${UBER_YAML}"
  assertEquals "Some matches were found matching a version other than expected, see output from yq above^^" 1 $?
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}