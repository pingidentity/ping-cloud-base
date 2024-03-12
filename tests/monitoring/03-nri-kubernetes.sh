#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"
. "${CI_SCRIPTS_DIR}"/test/test_utils.sh

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testNriBundleNrk8sKubeletIsRunning() {
  resource_name="pingaccess-was"
  resource_kind="nri-bundle-nrk8s-kubelet"
  resource_namespace="newrelic"
  verify_resource_with_sleep "${resource_kind}" "${resource_namespace}" "${resource_name}"

  assertEquals "One or few nri-bundle-nrk8s-kubelet pods are failed to run properly." 0 $?
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
