#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPingOneConfiguratorJobStatus() {

  status=$(kubectl get job pingone-configurator -n ${PING_CLOUD_NAMESPACE} -o json | jq -r '.status.conditions[0].type')
  assertEquals 0 $?
  assertEquals "The status of the pingone-configurator job should be Complete but was: ${status}" 'Complete' ${status}
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}