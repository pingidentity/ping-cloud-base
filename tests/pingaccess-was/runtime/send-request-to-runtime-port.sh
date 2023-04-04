#!/bin/bash

. "${PROJECT_DIR}"/tests/pingaccess/util/pa-test-utils.sh

send_request_to_runtime_port() {

  set +x

  engine_hostname="${1}"
  namespace="${2}"

  runtime_port_response=$(kubectl exec pingaccess-was-admin-0 -n ${namespace} \
      -c pingaccess-was-admin -- curl -k -s -i https://${engine_hostname}.pingaccess-was:3000/)

  response_code=$(parse_http_response_code "${runtime_port_response}")

  if [[ 403 -ne ${response_code} ]]; then
    log "At this point, it's assumed the PingAccess engines have not been configured to proxy for any applications."
    log "A 403 response is expected simply confirming the engine ${engine_hostname} is listening for requests on port 3000."
    log "The actual response was: ${runtime_port_response}"
    return 1
  fi

  return 0
}