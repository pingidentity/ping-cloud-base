#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  readonly SAMPLE_RULES="sample-rules"
  readonly SAMPLE_RULES_VERSION="6.0.2"
  readonly SAMPLE_SITE_AUTH="sample-site-authenticators"
  readonly SAMPLE_SITE_AUTH_VERSION="6.0.2"
  readonly SAMPLE_SITE_AUTH_VERSION_UPGRADE="6.0.3"
  readonly PRODUCT_NAME=pingaccess

  TEMP_FILE=$(mktemp)

  ENGINE_SERVERS=$( kubectl get pod -o name -n "${PING_CLOUD_NAMESPACE}" -l role=${PRODUCT_NAME}-engine | grep ${PRODUCT_NAME} | cut -d/ -f2)

  # Prepend admin server to list of runtime engine servers.
  SERVERS="${PRODUCT_NAME}-admin-0 ${ENGINE_SERVERS}"
}

oneTimeTearDown() {
  unset SERVERS
  unset ENGINE_SERVERS
  unset TEMP_FILE
}

# Helper Methods
set_artifact_list_json_file() {
  kubectl cp ${TEMP_FILE} "${SERVER}":/opt/staging/artifacts/artifact-list.json  -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}"
  kubectl exec "${SERVER}" -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c "cat /opt/staging/artifacts/artifact-list.json"
}
run_artifact_script() {
  # Set ARTIFACT_REPO_URL to "s3://ci-cd-artifacts-bucket" before running artifact script.
  # This bucket will always maintain the custom plugins to execute test.
  kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c \
    "ARTIFACT_REPO_URL=s3://ci-cd-artifacts-bucket; \
    /opt/staging/hooks/10-download-artifact.sh" > /dev/null 2>&1
  return ${?}
}
cleanup_artifacts() {
  kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c \
    "rm /opt/out/instance/lib/${SAMPLE_RULES}-${SAMPLE_RULES_VERSION}.jar" > /dev/null 2>&1

  kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c \
    "rm /opt/out/instance/lib/${SAMPLE_SITE_AUTH}-${SAMPLE_SITE_AUTH_VERSION}.jar" > /dev/null 2>&1
}

# Test Methods

# Validate when artifact JSON is an empty list.
# Script is expected to ignore JSON and exit with the non-status code 0.
testEmptyJson() {
  local expected_status_code=0
  local actual_status_code=

  log "Test empty JSON list"
  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"

#    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    cat > ${TEMP_FILE} <<-EOF
    []
EOF

    # Set file to empty list.
    set_artifact_list_json_file
    
    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code=${?}

    assertEquals "empty_json_test test failed" ${actual_status_code} ${expected_status_code}

  done
}

# Validate when artifact JSON is invalid.
# Script is expected to terminate and exit with the error code 1.
testInvalidJson() {
  local expected_status_code=1
  local actual_status_code=

  log "Test invalid JSON"
  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"

#    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    cat > ${TEMP_FILE} <<-EOF
    [{"name" "${SAMPLE_RULES}"}]
EOF

    # Set file to invalid JSON.
    set_artifact_list_json_file

    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code=${?}

    # Return 0 if the actual status code from an invalid JSON is is equal to the expected.
    assertEquals "invalid_json_test failed" ${actual_status_code} ${expected_status_code}

  done
}

# Validate when artifact JSON has duplicates.
# Script is expected to terminate and exit with the error code 1.
testDuplicateJson() {
  local expected_status_code=1
  local actual_status_code=

  log "Test duplicate artifacts"
  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"

#    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    cat > ${TEMP_FILE} <<-EOF
    [
      {
        "name": "${SAMPLE_RULES}",
        "version": "${SAMPLE_RULES_VERSION}"
      },
      {
        "name": "${SAMPLE_RULES}",
        "version": "${SAMPLE_RULES_VERSION}"
      }
    ]
EOF

    # Set file with duplicate artifacts.
    set_artifact_list_json_file

    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code=${?}

    # Return 0 if the actual status code of duplicates in JSON is equal to the expected.
    assertEquals "duplicate_json_test failed" ${actual_status_code} ${expected_status_code}

  done
}

# Validate when artifact JSON is missing plugin name.
# Script is expected to terminate and exit with the error code 1.
testMissingNameJson() {
  local expected_status_code=1
  local actual_status_code=

  log "Test missing artifact name in JSON"
  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"

#    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    cat > ${TEMP_FILE} <<-EOF
    [
      {
        "version": "${SAMPLE_RULES_VERSION}"
      }
    ]
EOF

    # Set file without artifact name.
    set_artifact_list_json_file

    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code=${?}

    # Return 0 if the actual status code of missing name in JSON is equal to the expected.
    assertEquals "missing_name_json_test failed" ${actual_status_code} ${expected_status_code}

  done
}

# Validate when artifact JSON is missing plugin version.
# Script is expected to terminate and exit with the error code 1.
testMissingVersionJson() {
  local expected_status_code=1
  local actual_status_code=

  log "Test missing artifact version in JSON"
  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"

#    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    cat > ${TEMP_FILE} <<-EOF
    [
      {
        "name": "${SAMPLE_RULES}"
      }
    ]
EOF

    # Set file without artifact version.
    set_artifact_list_json_file

    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code=${?}

    # Return 0 if the actual status code of missing version in JSON is equal to the expected.
    assertEquals "missing_version_json_test failed" ${actual_status_code} ${expected_status_code}

  done
}

# Deploy 2 custom plugins.
# Script is expected to successfully deploy plugins and exit with the non-status code 0.
testDeployValidArtifact() {
  local expected_status_code=0
  local actual_status_code_script=
  local actual_status_code_artifact_deploy=

  log "Test valid artifact deployment"
  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"

#    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    cat > ${TEMP_FILE} <<-EOF
    [
      {
        "name": "${SAMPLE_RULES}",
        "version": "${SAMPLE_RULES_VERSION}"
      },
      {
        "name": "${SAMPLE_SITE_AUTH}",
        "version": "${SAMPLE_SITE_AUTH_VERSION}"
      }
    ]
EOF

    # Cleanup custom artifacts from /opt/out/instance/lib.
    cleanup_artifacts

    # Set file to valid artifact plugins.
    set_artifact_list_json_file

    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code_script=${?}

    # Search for artifact plugin in /lib directory and capture status code.
    kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c \
    "test -f /opt/out/instance/lib/${SAMPLE_RULES}-${SAMPLE_RULES_VERSION}.jar && 
    test -f /opt/out/instance/lib/${SAMPLE_SITE_AUTH}-${SAMPLE_SITE_AUTH_VERSION}.jar" > /dev/null 2>&1
    actual_status_code_artifact_deploy=${?}

    # Return 0 if the actual status code of deploying valid artifacts is equal to the expected.
    assertEquals ${actual_status_code_script} ${expected_status_code}
    assertEquals ${actual_status_code_artifact_deploy} ${expected_status_code}

  done
}

# Upgrade custom plugin.
# Script is expected to successfully upgrade plugin and exit with the non-status code 0.
testUpgradeArtifactTest() {
  local expected_status_code=0
  local actual_status_code_script=
  local actual_status_code_artifact_deploy=

  log "Test upgrade artifact deployment"
  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"

#    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    cat > ${TEMP_FILE} <<-EOF
    [
      {
        "name": "${SAMPLE_SITE_AUTH}",
        "version": "${SAMPLE_SITE_AUTH_VERSION_UPGRADE}"
      }
    ]
EOF

    # Set file to upgraded artifact plugin.
    set_artifact_list_json_file

    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code_script=${?}

    # Search for upgraded artifact plugin in /lib directory and capture status code.
    kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c \
      "test -f /opt/out/instance/lib/${SAMPLE_SITE_AUTH}-${SAMPLE_SITE_AUTH_VERSION_UPGRADE}.jar" > /dev/null 2>&1
    actual_status_code_artifact_deploy=${?}

    # Return 0 if the actual status code of upgrading artifact is equal to the expected.
    assertEquals ${actual_status_code_script} ${expected_status_code}
    assertEquals ${actual_status_code_artifact_deploy} ${expected_status_code}

  done
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}