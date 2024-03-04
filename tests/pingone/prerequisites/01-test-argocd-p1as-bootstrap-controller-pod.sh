#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"
. "${CI_SCRIPTS_DIR}"/test/test_utils.sh

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testArgoP1ASBootstrapSucceeded() {
  resource_name="argocd-p1as-bootstrap"
  resource_kind="job"
  verify_resource_with_sleep "${resource_kind}" "argocd" "${resource_name}"
  assertEquals 0 $?
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}