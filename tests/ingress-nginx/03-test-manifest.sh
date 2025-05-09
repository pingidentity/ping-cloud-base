#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}/common.sh" "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# Global expected values
export nginx_expected_version="1.11.5"

testNGINXPublicVersionMatch() {
  # Ensure expected nginx version is used
  yq -e 'select(.metadata.labels."app.kubernetes.io/name" == "ingress-nginx-public" and .metadata.labels."app.kubernetes.io/version" != env(nginx_expected_version))' "${UBER_YAML}"
  assertEquals "Unexpected ingress-nginx version found!, see output from yq above^^" 1 $?
}

testNGINXPrivateVersionMatch() {
  # Ensure expected nginx version is used
  yq -e 'select(.metadata.labels."app.kubernetes.io/name" == "ingress-nginx-private" and .metadata.labels."app.kubernetes.io/version" != env(nginx_expected_version))' "${UBER_YAML}"
  assertEquals "Unexpected ingress-nginx version found!, see output from yq above^^" 1 $?
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}