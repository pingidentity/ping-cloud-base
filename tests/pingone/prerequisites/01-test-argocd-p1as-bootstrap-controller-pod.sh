#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testArgoP1ASBootstrapSucceeded() {
  status=$(kubectl get pods --selector=job-name=argocd-p1as-bootstrap -n argocd -o json | jq -r '.items[].status.phase')
  assertEquals 0 $?
  assertEquals "The status of the p14c-bootstrap pod should be Succeeded but was: ${status}" "${status}" "Succeeded"
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}