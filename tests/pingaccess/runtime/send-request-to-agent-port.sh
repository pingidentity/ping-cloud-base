#!/bin/bash

. "${PROJECT_DIR}"/tests/pingaccess/util/pa-test-utils.sh

send_request_to_agent_port() {

  set +x

  agent_name="${1}"
  shared_secret="${2}"
  engine_hostname="${3}"
  namespace="${4}"

  agent_port_runtime_response=$(kubectl exec pingaccess-admin-0 -n ${namespace} \
    -c pingaccess-admin -- curl -k -s -i -H "vnd-pi-v: 1.0" \
    -H "vnd-pi-authz: Bearer ${agent_name}:${shared_secret}" \
    -H "X-Forwarded-Proto: https" -H "X-Forwarded-Host: httpbin" \
    -H "X-Forwarded-For: 127.0.0.1" https://${engine_hostname}.pingaccess:3030/)

  response_code=$(parse_http_response_code "${agent_port_runtime_response}")

  if [[ 277 -ne ${response_code} ]]; then
    log "There was a problem contacting the agent port on the engine instance:"
    log "${agent_port_runtime_response}"
    return 1
  fi

  return 0
}