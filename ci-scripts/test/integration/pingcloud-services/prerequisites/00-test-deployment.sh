#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testP14COAuthDeploymentAvailability() {

  status=$(kubectl get deployment p14c-oauth-service -o json | jq -r '.status.conditions[0].type')
  assertEquals 0 $?
  assertEquals "The status of the p14c-oauth-service deployment should be Available but was: ${status}" 'Available' ${status}
}

testP14CBootstrapDeploymentAvailability() {

  status=$(kubectl get deployment p14c-bootstrap -o json | jq -r '.status.conditions[0].type')
  assertEquals 0 $?
  assertEquals "The status of the p14c-bootstrap deployment should be Available but was: ${status}" 'Available' ${status}
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}