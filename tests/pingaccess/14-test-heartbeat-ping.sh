#!/bin/bash

# Ensure heartbeat public endpoints return null object

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}/common.sh" "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  # Wait for DNS resolution to be available
  pingaccess_ingress="$(kubectl get ingress pingaccess-ingress -n ${PING_CLOUD_NAMESPACE} -o jsonpath='{.spec.tls[*].hosts[0]}')"
  log "pingaccess-ingress: ${pingaccess_ingress}"
  dns_check=$(curl -k -s https://${pingaccess_ingress})
  exit_code=$?

  declare -r unable_to_resolve=6
  declare -r max_attempts=5
  for attempt in $(seq 1 ${max_attempts}); do
    log "Trying DNS resolution for pingaccess-ingress (attempt ${attempt})"
    dns_check=$(curl -k -s https://${pingaccess_ingress})
    exit_code=$?

    # Successful DNS resolution
    if [[ ${exit_code} != ${unable_to_resolve} ]]; then
        log "DNS resolution successful on attempt ${attempt}"
        break
    fi

    # Failed DNS resolution
    if [[ ${exit_code} == ${unable_to_resolve} ]]; then
        log "DNS resolution failed on attempt ${attempt} with exit code ${exit_code}"
    fi

    # Check if maximum attempts reached
    if [[ ${attempt} == ${max_attempts} ]]; then
      log "Maximum DNS resolution attempts (${max_attempts}) reached!"
      log "Aborting test suite"
      exit 1
    fi

    sleep 10
  done
}

# PingAccess heartbeat test cases

testHeartBeatPARegular() {
  # Regular request
  response=$(curl -k -s -w "|%{http_code}" "https://${pingaccess_ingress}/pa/heartbeat.ping")
  body=${response%|*}
  http_code=${response#*|}
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${body}"
  assertEquals "PingAccess heartbeat received unexpected HTTP response code: ${http_code}" "200" "${http_code}"
}

testHeartBeatPAEncodedPeriod() {
  # Encoded '.'
  response=$(curl -k -s -w "|%{http_code}" "https://${pingaccess_ingress}/pa/heartbeat%2Eping")
  body=${response%|*}
  http_code=${response#*|}
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${body}"
  assertEquals "PingAccess heartbeat received unexpected HTTP response code: ${http_code}" "200" "${http_code}"
}

testHeartBeatPAPathTraversal() {
  # Path traversal
  response=$(curl -k -s -w "|%{http_code}" "https://${pingaccess_ingress}/pa/something/../heartbeat.ping")
  body=${response%|*}
  http_code=${response#*|}
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${body}"
  assertEquals "PingAccess heartbeat received unexpected HTTP response code: ${http_code}" "200" "${http_code}"
}

testHeartBeatPAEncodedSlash() {
  # Encoded '/'
  response=$(curl -k -s -w "|%{http_code}" "https://${pingaccess_ingress}/pa%2Fheartbeat.ping")
  body=${response%|*}
  http_code=${response#*|}
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${body}"
  assertEquals "PingAccess heartbeat received unexpected HTTP response code: ${http_code}" "200" "${http_code}"
}

testHeartBeatPAPathParameterObfuscation() {
  # Path Parameter Obfuscation (Matrix URIs)
  response=$(curl -k -s -w "|%{http_code}" "https://${pingaccess_ingress}/pa/heartbeat.ping;junkparam=blah")
  body=${response%|*}
  http_code=${response#*|}
  # PingAccess returns 404 Not Found with path parameter obfuscation
  assertTrue "PingAccess heartbeat response should contain 'Not Found'" "echo '${body}' | grep -q 'Not Found'"
  assertEquals "PingAccess heartbeat received unexpected HTTP response code: ${http_code}" "404" "${http_code}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}