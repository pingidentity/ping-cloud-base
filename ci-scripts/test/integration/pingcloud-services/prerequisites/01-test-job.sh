#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPingFederateAdminConfiguratorJobStatus() {

  status=$(kubectl get job pingfederate-admin-configurator -n ${NAMESPACE} -o json | jq -r '.status.conditions[0].type')
  assertEquals 0 $?
  assertEquals "The status of the pingfederate-admin-configurator job should be Complete but was: ${status}" 'Complete' ${status}
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}