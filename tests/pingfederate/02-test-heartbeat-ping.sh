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
  pingfederate_ingress="$(kubectl get ingress pingfederate-ingress -n ${PING_CLOUD_NAMESPACE} -o jsonpath='{.spec.tls[*].hosts[0]}')"
  log "pingfederate-ingress: ${pingfederate_ingress}"
  dns_check=$(curl -k -s https://${pingfederate_ingress})
  exit_code=$?

  declare -r unable_to_resolve=6
  declare -r max_attempts=5
  for attempt in $(seq 1 ${max_attempts}); do
    log "Trying DNS resolution for pingfederate-ingress (attempt ${attempt})"
    dns_check=$(curl -k -s https://${pingfederate_ingress})
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

# PingFederate heartbeat test cases

testHeartBeatPFRegular() {
  # Regular request
  response=$(curl -k -s -w "|%{http_code}" "https://${pingfederate_ingress}/pf/heartbeat.ping")
  body=${response%|*}
  http_code=${response#*|}
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${body}"
  assertEquals "PingAccess heartbeat received unexpected HTTP response code: ${http_code}" "200" "${http_code}"
}

testHeartBeatPFEncodedPeriod() {
  # Encoded '.'
  response=$(curl -k -s -w "|%{http_code}" "https://${pingfederate_ingress}/pf/heartbeat%2Eping")
  body=${response%|*}
  http_code=${response#*|}
  assertEquals "PingFederate heartbeat response code was not empty object" "{}" "${body}"
  assertEquals "PingFederate heartbeat received unexpected HTTP response code: ${http_code}" "200" "${http_code}"
}

testHeartBeatPFPathTraversal() {
  # Path traversal
  response=$(curl -k -s -w "|%{http_code}" "https://${pingfederate_ingress}/pf/something/../heartbeat.ping")
  body=${response%|*}
  http_code=${response#*|}
  assertEquals "PingFederate heartbeat response code was not empty object" "{}" "${body}"
  assertEquals "PingFederate heartbeat received unexpected HTTP response code: ${http_code}" "200" "${http_code}"
}

testHeartBeatPFEncodedSlash() {
  # Encoded '/'
  response=$(curl -k -s -w "|%{http_code}" "https://${pingfederate_ingress}/pf%2Fheartbeat.ping")
  body=${response%|*}
  http_code=${response#*|}
  assertEquals "PingFederate heartbeat response code was not empty object" "{}" "${body}"
  assertEquals "PingFederate heartbeat received unexpected HTTP response code: ${http_code}" "200" "${http_code}"
}

testHeartBeatPFPathParameterObfuscation() {
  # Path Parameter Obfuscation (Matrix URIs)
  response=$(curl -k -s -w "|%{http_code}" "https://${pingfederate_ingress}/pf/heartbeat.ping;junkparam=blah")
  body=${response%|*}
  http_code=${response#*|}
  # PingFederate returns 200 OK with empty object even with path parameter obfuscation
  assertEquals "PingFederate heartbeat response code was not empty object" "{}" "${body}"
  assertEquals "PingFederate heartbeat received unexpected HTTP response code: ${http_code}" "200" "${http_code}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}