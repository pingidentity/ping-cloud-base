#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

get_pods_state() {
  max_retries=10  # You can adjust the number of retries as needed
  retry_interval=5  # Adjust the sleep interval (in seconds) between retries

  for ((i = 0; i < $max_retries; i++)); do
    pods=$(kubectl get pods -l $1 -n $2 -o json | jq -r '.items[] | .metadata.name')
    if [ -n "$pods" ]; then
      all_running=true
      for pod in $pods; do
        phase=$(kubectl get pod $pod -n $2 -o json | jq -r '.status.phase')
        if [[ "$phase" != "Running" ]]; then
          all_running=false
          break
        fi
      done
      if [ "$all_running" = true ]; then
        return 0  # All pods are in the "Running" state
      fi
    fi

    if [ "$i" -lt $((max_retries - 1)) ]; then
      sleep $retry_interval  # Sleep before the next retry
    fi
  done

  return 1  # Pods did not reach the "Running" state after max_retries
}

testNriBundleNrk8sKubeletIsRunning() {
  time get_pods_state "app.kubernetes.io/component=kubelet" "newrelic"
  assertEquals "One or few nri-bundle-nrk8s-kubelet pods are failed to run properly." 0 $?
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
