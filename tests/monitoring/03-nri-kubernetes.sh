#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testNriBundleNrk8sKubeletIsRunning() {
  kubectl wait pod -l app.kubernetes.io/component=kubelet -n newrelic --for=condition=Ready=true --timeout=60s
  assertEquals "One or few nri-bundle-nrk8s-kubelet pods are failed to run properly." 0 $?
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
