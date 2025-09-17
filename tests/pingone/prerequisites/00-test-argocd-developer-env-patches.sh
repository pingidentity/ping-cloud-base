#!/bin/bash

# Tests for ArgoCD patches made to developer environments (IS_BELUGA_ENV=true) in generate-cluster-state.sh

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testArgoBootstrapConfigmapHasRegionEnvVars() {
  cm_json=$(kubectl get cm argocd-bootstrap -n argocd -o json)
  cm_keys=$(jq -r '.data | keys' <<< "${cm_json}")
  found=$(jq -r '.data | has("REGION")' <<< "${cm_json}")
  assertEquals 0 $?
  assertTrue "The ArgoCD region env vars were not found in the keys of the argocd-bootstrap configmap: ${cm_keys}" "${found}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}