#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testP14COAuthPodAvailability() {
  status=$(kubectl get pods --selector=job-name=p14c-oauth-service -n ${PING_CLOUD_NAMESPACE} -o json | jq -r '.items[].status.phase')
  assertEquals 0 $?
  # There may be multiple pods from failed jobs, but if at least one succeeds we're good
  assertContains "The status phase of the p14c-oauth-service pod should be Succeeded but was: ${status}" "${status}" "Succeeded"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}