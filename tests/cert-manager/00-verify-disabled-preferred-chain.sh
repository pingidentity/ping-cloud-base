#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testEnabledCertManagerPreferredChain() {
  preferred_chain_response=$(kubectl get clusterissuer letsencrypt-prod -o jsonpath='{.spec.acme.preferredChain}')
  assertEquals \
    "The preferredChain from the k8s resource ClusterIssuer 'letsencrypt-prod' should be set to ISRG Root X1" \
    "ISRG Root X1" \
    "${preferred_chain_response}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}