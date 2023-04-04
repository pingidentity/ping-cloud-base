#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPingOneConfiguratorPodStatus() {
  status=$(kubectl get pods --selector=role=pingone-configurator -n ${PING_CLOUD_NAMESPACE} -o json | jq -r '.items[].status.phase')
  assertEquals 0 $?
  assertEquals "The status phase of the pingone-configurator pod should be Succeeded but was: ${status}" 'Succeeded' ${status}
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}