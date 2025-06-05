#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"


if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

#Function to get the full pod name based on the prefix name 'pingcentral'
get_pod_name() {
  kubectl get pods -n "${PING_CLOUD_NAMESPACE}" --no-headers -o custom-columns=":metadata.name" | grep "^pingcentral" | head -n 1
}


testAlpineVersion() {

  POD_NAME=$(get_pod_name)
  log "Test: Verify Alpine Version: ${POD_NAME}"

  # Positive Check
  kubectl exec -n "$PING_CLOUD_NAMESPACE" "$POD_NAME" -c pingcentral  -- sh -c \
    "grep -q \"$PRODUCT_ALPINE_VERSION\" /etc/alpine-release" > /dev/null 2>&1
  assertEquals "Validation failed on expected Alpine version: $PRODUCT_ALPINE_VERSION" 0 $?

  #Negative check
  kubectl exec -n "$PING_CLOUD_NAMESPACE" "$POD_NAME" -c pingcentral -- sh -c \
     "grep -q '0.0.0.0' /etc/alpine-release" > /dev/null 2>&1
  assertNotEquals "Alpine version 0.0.0.0 was incorrectly accepted" 0 $?
}

testProductVersion() {
  POD_NAME=$(get_pod_name)
  log "Test: Verify Product Version"

    # Positive check
     kubectl exec -n "$PING_CLOUD_NAMESPACE" "$POD_NAME" -c pingcentral -- sh -c \
       "unzip -p /opt/out/instance/ping-central.jar META-INF/maven/com.pingidentity.pass/ping-central/pom.properties | grep -q \"version=$PRODUCT_VERSION\""   > /dev/null 2>&1
     assertEquals "Validation failed on expected Product version: $PRODUCT_VERSION" 0 $?

     # Negative check
     kubectl exec -n "$PING_CLOUD_NAMESPACE" "$POD_NAME" -c pingcentral -- sh -c \
       "unzip -p /opt/out/instance/ping-central.jar META-INF/maven/com.pingidentity.pass/ping-central/pom.properties | grep -q 'version=0.0.0.0'"  > /dev/null 2>&1
     assertNotEquals "Product version 0.0.0.0 was incorrectly accepted" 0 $?


}

testJavaVersion() {
  POD_NAME=$(get_pod_name)
  log "Test: Verify Java Version"

  # Positive Check
  kubectl exec -n "$PING_CLOUD_NAMESPACE" "$POD_NAME" -c pingcentral -- sh -c \
    "java -version 2>&1 | grep -q \"$PRODUCT_JAVA_VERSION\"" > /dev/null 2>&1
  assertEquals "Validation failed on expected Java version: $PRODUCT_JAVA_VERSION" 0 $?

  # Negative Check
  kubectl exec -n "$PING_CLOUD_NAMESPACE" "$POD_NAME" -c pingcentral -- sh -c \
      'java -version 2>&1 | grep -q "0.0.0.0" ' > /dev/null 2>&1
  assertNotEquals "Java version 0.0.0.0 was incorrectly accepted" 0 $?
}


shift $#

. ${SHUNIT_PATH}