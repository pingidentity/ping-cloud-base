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

isPortOpen() {
  local ingress=$1
  local hostname=$(kubectl get ingress "${ingress}" -n "${PING_CLOUD_NAMESPACE}" -o jsonpath='{.spec.rules[*].host}')
  log "ingress: ${ingress}"
  log "Hostname: ${hostname}"

  # --- Retry Logic ---
  local max_attempts=5
  local sleep_duration=10 # seconds
  local attempt=1

  # Retry logic for PD port open test
  for (( attempt=1; attempt<=max_attempts; attempt++ )); do
    log "Attempt ${attempt} to check if port 636 is open on ${hostname}"
    kubectl exec pingdirectory-0 -c pingdirectory -n "${PING_CLOUD_NAMESPACE}" -- sh -c \
      "nc -zv -w 10 ${hostname} 636"
    EXIT_CODE=$?
    log "Port 636 check exit code: ${EXIT_CODE}"
    if [ ${EXIT_CODE} -eq 0 ]; then
      log "Port 636 is open on ${hostname} on attempt ${attempt}"
      return 0
    else
      log "Port 636 is closed on ${hostname} on attempt ${attempt}, retrying in ${sleep_duration} seconds..."
      sleep ${sleep_duration}
    fi
  done
  log "Port 636 check failed after ${max_attempts} attempts"
  assertEquals 0 $EXIT_CODE
}

runLDAPSearch() {
  local ingress=$1
  local hostname=$(kubectl get ingress "${ingress}" -n "${PING_CLOUD_NAMESPACE}" -o jsonpath='{.spec.rules[*].host}')
  log "ingress: ${ingress}"
  log "Hostname: ${hostname}"

  # --- Retry Logic ---
  local max_attempts=5
  local sleep_duration=10 # seconds
  local attempt=1

  # Retry logic for ldapsearch test
  for (( attempt=1; attempt<=max_attempts; attempt++ )); do
    log "Attempt ${attempt} to run ldapsearch against hostname ${hostname}"
    kubectl exec pingdirectory-0 -c pingdirectory -n "${PING_CLOUD_NAMESPACE}" -- sh -c \
      "ldapsearch \
        -h ${hostname} -p 636 \
        --terse --bindDN 'cn=administrator' \
        --bind-password '2FederateM0re' --useSSL \
        --trustAll --baseDN 'cn=config' \
        --searchScope base '(&)' 1.1"
    EXIT_CODE=$?
    log "ldapsearch exit code: ${EXIT_CODE}"
    if [ ${EXIT_CODE} -eq 0 ]; then
      log "ldapsearch succeeded on attempt ${attempt}"
      return 0
    else
      log "ldapsearch failed on attempt ${attempt}, retrying in ${sleep_duration} seconds..."
      sleep ${sleep_duration}
    fi
  done
  log "ldapsearch failed after ${max_attempts} attempts"
  assertEquals 0 $EXIT_CODE
}

testPDAdminIngressCreated(){
  log "Checking that ${PASSTHROUGH_INGRESS} has been created"
  check_ingress_information "${PASSTHROUGH_INGRESS}"
  log "Checking that ${TERMINATING_INGRESS} has been created"
  check_ingress_information "${TERMINATING_INGRESS}"
}

testPorts() {
  log "Testing that port 636 is open on ${PASSTHROUGH_INGRESS} ingress"
  isPortOpen "${PASSTHROUGH_INGRESS}"
  log "Testing that port 636 is open on ${TERMINATING_INGRESS} ingress"
  isPortOpen "${TERMINATING_INGRESS}"
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