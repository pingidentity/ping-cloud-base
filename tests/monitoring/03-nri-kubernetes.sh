#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

get_pods_state() {
  pods=$(kubectl get pods -l $1 -n $2  -o json | jq -r '.items[] | .metadata.name')
  if [ -n "$pods" ]; then
      for pod in $pods
      do
          phase=$(kubectl get pod $pod -n $2 -o json | jq -r '.status.phase')
          [[ "$phase" != "Running" ]] && return 1;
      done
  fi
  return 0
}

testNriBundleNrk8sKubeletIsRunning() {
  get_pods_state "app.kubernetes.io/component=kubelet" "newrelic"
  assertEquals "One or few nri-bundle-nrk8s-kubelet pods are failed to run properly." 0 $?
}

testNriBundleNrk8sControlplaneIsRunning() {
  get_pods_state "app.kubernetes.io/component=controlplane" "newrelic"
  assertEquals "One or few nri-bundle-nrk8s-controlplane pods are failed to run properly." 0 $?
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
