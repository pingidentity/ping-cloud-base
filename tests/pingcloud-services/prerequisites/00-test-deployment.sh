#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"
. "${CI_SCRIPTS_DIR}"/test/test_utils.sh

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testP14COAuthDeploymentAvailability() {

  status=$(kubectl get deployment p14c-oauth-service -n ${PING_CLOUD_NAMESPACE} -o json | jq -r '.status.conditions[] | select(.type == "Available") | .status')
  assertEquals 0 $?
  assertEquals "The Available status of the p14c-oauth-service deployment should be True but was: ${status}" 'True' ${status}
}

testP14CBootstrapDeploymentAvailability() {

  status=$(kubectl get deployment p14c-bootstrap -n ${PING_CLOUD_NAMESPACE} -o json | jq -r '.status.conditions[] | select(.type == "Available") | .status')
  assertEquals 0 $?
  assertEquals "The Available status of the p14c-bootstrap deployment should be True but was: ${status}" 'True' ${status}
}

testP14CBOMDeploymentAvailability() {
  status=$(kubectl get deployment p14c-bom-service -n ${PING_CLOUD_NAMESPACE} -o json| jq -r '.status.conditions[] | select(.type == "Available") | .status')
  assertEquals 0 $?
  assertEquals "The Available status of the p14c-bom-service deployment should be True but was: ${status}" 'True' ${status}
}  

testMetadataAvailability() {

  exit_code=0
  for i in {1..10}
  do
    testUrlsWithoutBasicAuthExpect2xx "${PINGCLOUD_METADATA}"
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
      log "The Pingcloud-metadata endpoint is inaccessible.  This is attempt ${i} of 10.  Wait 60 seconds and then try again..."
      sleep 60
    else
      break
    fi
  done

  assertEquals 0 $exit_code
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}