#!/bin/bash

# Tests for ArgoCD patches made to developer environments (IS_BELUGA_ENV=true) in generate-cluster-state.sh

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testArgoHostInPAWASIngress() {
  ingress_json=$(kubectl get ingress pingaccess-was-ingress -n ping-cloud -o json)
  ingress_hosts=$(jq -r '.spec.tls[0].hosts' <<< "${ingress_json}")
  found=$(jq -r 'any(.spec.tls[0]; .hosts[] | startswith("argocd"))' <<< "${ingress_json}")
  assertEquals 0 $?
  assertTrue "The ArgoCD host was not found in the pingaccess-was-ingress list of hosts: ${ingress_hosts}" "${found}"
}

testArgoRuleInPAWASIngress() {
  ingress_json=$(kubectl get ingress pingaccess-was-ingress -n ping-cloud -o json)
  ingress_rule_hosts=$(jq -r '[.spec.rules[].host]' <<< "${ingress_json}")
  found=$(jq -r 'any(.spec.rules[]; .host | startswith("argocd"))' <<< "${ingress_json}")
  assertEquals 0 $?
  assertTrue "The ArgoCD rule was not found in the pingaccess-was-ingress list of rule hosts: ${ingress_rule_hosts}" "${found}"
}

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