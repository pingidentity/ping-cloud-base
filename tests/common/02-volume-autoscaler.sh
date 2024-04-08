#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# Regex pattern for the grep over not ignored PVCs
scalablePVCs="data-opensearch-cluster-*\|logstash-gp3-logstash-*\|prometheus-storage-volume-*"

# List of PVCs allowed for the volume autoscaler
notIgnoredPVCs=$(kubectl get pvc -A -o json | jq '.items[].metadata|select(.annotations."volume.autoscaler.kubernetes.io/ignore"!="true")|.name')

testVolumeAutoscaler() {
  # This test will fail if there are PVCs that are not ignored and are not in the list of scalable PVCs
  echo "${notIgnoredPVCs}" | tr -d '"' | grep -v "${scalablePVCs}"
  # Grep -v return 1 if no results are found. We expect 1 here.
  assertEquals "Some of the PVCs are not ignored and are not in the allowed list" 1 $?
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
