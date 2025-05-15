#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"


if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

POD_NAME=$(kubectl get pods -n "$PING_CLOUD_NAMESPACE" --no-headers -o custom-columns=":metadata.name" | grep "^pingdelegator" | head -n 1)


testAlpineVersion() {
  log "Test: Verify Alpine Version"

  # Positive Check
  kubectl exec -n "$PING_CLOUD_NAMESPACE" "$POD_NAME" -c pingdelegator -- sh -c \
    "grep -q \"$PRODUCT_ALPINE_VERSION\" /etc/alpine-release"
  assertEquals "Validation failed on expected Alpine version: $PRODUCT_ALPINE_VERSION" 0 $?

  #Negative check
  kubectl exec -n "$PING_CLOUD_NAMESPACE" "$POD_NAME" -c pingdelegator -- sh -c \
    "grep -q '0.0.0.0' /etc/alpine-release" > /dev/null 2>&1
  assertNotEquals "Alpine version 0.0.0.0 was incorrectly accepted" 0 $?

}



shift $#

. ${SHUNIT_PATH}