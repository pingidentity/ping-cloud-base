#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

restartNginx() {
  local namespace=$1
  log "Rolling Nginx ingress controllers to pick up change"
  kubectl rollout restart deployment nginx-ingress-controller -n "$namespace"

  log "Waiting for nginx pods to be ready..."
  kubectl rollout status deployment nginx-ingress-controller -n "$namespace"
}

oneTimeSetUp() {
  local namespace="ingress-nginx-public"
  local configmap="nginx-configuration"

  log "Updating $configmap configmap to enable ocsp stapling"
  kubectl patch configmap "$configmap" -n "$namespace" --patch '{
    "data": {
      "enable-ocsp": "true"
    }
  }'
  restartNginx "$namespace"
  sleep 15
}

oneTimeTearDown() {
  local namespace="ingress-nginx-public"
  local configmap="nginx-configuration"
  log "Removing patch from $configmap configmap"
  kubectl patch configmap "$configmap" -n "$namespace" --type=json --patch '[
    {
      "op": "remove",
      "path": "/data/enable-ocsp"
    }
  ]'
  restartNginx "$namespace"

}

testOCSPEnabled() {
  local endpoint=$(echo "$PINGCLOUD_METADATA_API" | sed 's/https:\/\///')
  log "Endoint to use: $endpoint"
  expected_output="OCSP Response Status: successful (0x0)"
  ocsp_response=$(openssl s_client -connect $endpoint:443 -status </dev/null 2>/dev/null \
    | grep "$expected_output" | sed 's/^[[:space:]]*//')
  
  assertEquals "$expected_output" "$ocsp_response"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}