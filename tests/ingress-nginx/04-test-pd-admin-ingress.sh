#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}/common.sh" "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

PASSTHROUGH_INGRESS="pingdirectory-admin-passthrough-ingress"
TERMINATING_INGRESS="pingdirectory-admin-ingress"

check_ingress_information() {
  local ingress=$1
  local ingress_object=$(kubectl get ingress "${ingress}" -n "${PING_CLOUD_NAMESPACE}")
  assertNotNull "NGINX ingress ${ingress} was unexpectedly empty." "${ingress_object}"
  
  local ingress_class=$(kubectl get ingress "${ingress}" -n "${PING_CLOUD_NAMESPACE}" -o jsonpath='{.spec.ingressClassName}')
  assertEquals "Nginx ${ingress} is not private" "nginx-private" "${ingress_class}"
}

runLDAPSearch() {
  local ingress=$1
  local hostname=$(kubectl get ingress "${ingress}" -n "${PING_CLOUD_NAMESPACE}" -o jsonpath='{.spec.rules[*].host}')
  kubectl exec pingdirectory-0 -c pingdirectory -n "${PING_CLOUD_NAMESPACE}" -- sh -c \
    "ldapsearch \
      -h ${hostname} -p 636 \
      --terse --bindDN 'cn=administrator' \
      --bind-password '2FederateM0re' --useSSL \
      --trustAll --baseDN 'cn=config' \
      --searchScope base '(&)' 1.1"
  assertEquals 0 $?
}

testPDAdminIngressCreated(){
  log "Checking that ${PASSTHROUGH_INGRESS} has been created"
  check_ingress_information "${PASSTHROUGH_INGRESS}"
  log "Checking that ${TERMINATING_INGRESS} has been created"
  check_ingress_information "${TERMINATING_INGRESS}"
}

testLDAPS() {
  log "Running ldapsearch against ${PASSTHROUGH_INGRESS} ingress"
  runLDAPSearch "${PASSTHROUGH_INGRESS}"
  log "Running ldapsearch against ${TERMINATING_INGRESS} ingress"
  runLDAPSearch "${TERMINATING_INGRESS}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}