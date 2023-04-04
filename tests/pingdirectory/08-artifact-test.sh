#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  PRODUCT_NAME="pingdirectory"

  NUM_REPLICAS=$(kubectl get statefulset "${PRODUCT_NAME}" -o jsonpath='{.spec.replicas}' -n "${PING_CLOUD_NAMESPACE}")

  TEMP_FILE=$(mktemp)

  PINGDATA_EXT_ARTIFACT_NAME="pingdata-extensions"
  PINGDATA_EXT_ARTIFACT_VERSION="1.0.2"
  PINGDATA_EXT_ARTIFACT_FILENAME="${PINGDATA_EXT_ARTIFACT_NAME}-${PINGDATA_EXT_ARTIFACT_VERSION}.zip"

  CONTAINER="${PRODUCT_NAME}"

  ARTIFACT_JSON="/opt/staging/artifacts/artifact-list.json"
  ARTIFACT_JSON_BACKUP="${ARTIFACT_JSON}-backup"
  TARGET_DIR="/opt/staging/pd.profile/server-sdk-extensions"
  TARGET_DIR_BACKUP="${TARGET_DIR}-backup"

  # Backup artifact related files.
  REPLICA_INDEX=$((NUM_REPLICAS - 1))
  while test ${REPLICA_INDEX} -gt -1; do
    SERVER="${PRODUCT_NAME}-${REPLICA_INDEX}"

    kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c "cp ${ARTIFACT_JSON} ${ARTIFACT_JSON_BACKUP}"
    
    kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c "cp -r ${TARGET_DIR} ${TARGET_DIR_BACKUP}"
    kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c "rm -rf ${TARGET_DIR}/*"

    REPLICA_INDEX=$((REPLICA_INDEX - 1))
  done
}

oneTimeTearDown() {
  [[ "${_shunit_name_}" = 'EXIT' ]] && return 0

  # Restore artifact related files.
  REPLICA_INDEX=$((NUM_REPLICAS - 1))
  while test ${REPLICA_INDEX} -gt -1; do
    SERVER="${PRODUCT_NAME}-${REPLICA_INDEX}"

    kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c "mv -f ${ARTIFACT_JSON_BACKUP} ${ARTIFACT_JSON}"

    kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c "rm -rf ${TARGET_DIR}"
    kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c "mv ${TARGET_DIR_BACKUP} ${TARGET_DIR}"

    REPLICA_INDEX=$((REPLICA_INDEX - 1))
  done
}

tearDown() {
  [[ "${_shunit_name_}" = 'EXIT' ]] && return 0

  # Set to clean testing state.
  REPLICA_INDEX=$((NUM_REPLICAS - 1))
  while test ${REPLICA_INDEX} -gt -1; do
    SERVER="${PRODUCT_NAME}-${REPLICA_INDEX}"

    kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c "cp ${ARTIFACT_JSON_BACKUP} ${ARTIFACT_JSON}"

    kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c "rm -rf ${TARGET_DIR}/*"
    
    REPLICA_INDEX=$((REPLICA_INDEX - 1))
  done
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
    "ARTIFACT_REPO_URL=${ARTIFACT_REPO_URL}; \
    /opt/staging/hooks/10-download-artifact.sh" > /dev/null 2>&1
  return ${?}
}

# Test Methods

# Validate when artifact JSON is an empty list.
# Script is expected to ignore JSON and exit with the non-status code 0.
testEmptyJson() {
  local expected_status_code=0

  REPLICA_INDEX=$((NUM_REPLICAS - 1))
  while test ${REPLICA_INDEX} -gt -1; do
    SERVER="${PRODUCT_NAME}-${REPLICA_INDEX}"

    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    cat > ${TEMP_FILE} <<-EOF
    []
EOF

    # Set file to empty list.
    set_artifact_list_json_file
    
    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code=${?}

    assertEquals "empty_json_test test failed" ${expected_status_code} ${actual_status_code}

    REPLICA_INDEX=$((REPLICA_INDEX - 1))
  done
}

# Script is expected to terminate and exit with the error code 1.
testInvalidJson() {
  local expected_status_code=1

  REPLICA_INDEX=$((NUM_REPLICAS - 1))
  while test ${REPLICA_INDEX} -gt -1; do
    SERVER="${PRODUCT_NAME}-${REPLICA_INDEX}"

    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    cat > ${TEMP_FILE} <<-EOF
    [{"name" "${PINGDATA_EXT_ARTIFACT_NAME}"}]
EOF

    # Set file to invalid JSON.
    set_artifact_list_json_file

    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code=${?}

    # Return 0 if the actual status code from an invalid JSON is is equal to the expected.
    assertEquals "invalid_json_test failed" ${expected_status_code} ${actual_status_code} 

    REPLICA_INDEX=$((REPLICA_INDEX - 1))
  done
}

# Validate when artifact JSON has duplicates.
# Script is expected to terminate and exit with the error code 1.
testDuplicateJson() {
  local expected_status_code=1

  log "Test duplicate artifacts"
  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"

    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    cat > ${TEMP_FILE} <<-EOF
    [
      {
        "name": "${PINGDATA_EXT_ARTIFACT_NAME}",
        "version": "${PINGDATA_EXT_ARTIFACT_VERSION}"
      },
      {
        "name": "${PINGDATA_EXT_ARTIFACT_NAME}",
        "version": "${PINGDATA_EXT_ARTIFACT_VERSION}"
      }
    ]
EOF

    # Set file with duplicate artifacts.
    set_artifact_list_json_file

    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code=${?}

    # Return 0 if the actual status code of duplicates in JSON is equal to the expected.
    assertEquals "duplicate_json_test failed" ${expected_status_code} ${actual_status_code}

  done
}

# Validate when artifact JSON is missing artifact name.
# Script is expected to terminate and exit with the error code 1.
testMissingNameJson() {
  local expected_status_code=1

  log "Test missing artifact name in JSON"

  REPLICA_INDEX=$((NUM_REPLICAS - 1))
  while test ${REPLICA_INDEX} -gt -1; do
    SERVER="${PRODUCT_NAME}-${REPLICA_INDEX}"

    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    cat > ${TEMP_FILE} <<-EOF
    [
      {
        "version": "${PINGDATA_EXT_ARTIFACT_VERSION}"
      }
    ]
EOF

    # Set file without artifact name.
    set_artifact_list_json_file

    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code=${?}

    # Return 0 if the actual status code of missing name in JSON is equal to the expected.
    assertEquals "missing_name_json_test failed" ${expected_status_code} ${actual_status_code}

    REPLICA_INDEX=$((REPLICA_INDEX - 1))
  done
}

# Validate when artifact JSON is missing artifact version.
# Script is expected to terminate and exit with the error code 1.
testMissingVersionJson() {
  local expected_status_code=1

  log "Test missing artifact version in JSON"

  REPLICA_INDEX=$((NUM_REPLICAS - 1))
  while test ${REPLICA_INDEX} -gt -1; do
    SERVER="${PRODUCT_NAME}-${REPLICA_INDEX}"

    # Set the container name.
    test "${SERVER}" == "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"

    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    cat > ${TEMP_FILE} <<-EOF
    [
      {
        "name": "${PINGDATA_EXT_ARTIFACT_NAME}"
      }
    ]
EOF

    # Set file without artifact version.
    set_artifact_list_json_file

    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code=${?}

    # Return 0 if the actual status code of missing version in JSON is equal to the expected.
    assertEquals "missing_version_json_test failed" ${expected_status_code} ${actual_status_code}

    REPLICA_INDEX=$((REPLICA_INDEX - 1))
  done
}

# Deploy an artifact.
# Script is expected to successfully deploy the artifact and exit with the non-status code 0.
testDeployValidArtifact() {
  local expected_status_code=0

  log "Test valid artifact deployment"
  
  REPLICA_INDEX=$((NUM_REPLICAS - 1))
  while test ${REPLICA_INDEX} -gt -1; do
    SERVER="${PRODUCT_NAME}-${REPLICA_INDEX}"

    log "Observing logs: Server: ${SERVER}, Container: ${CONTAINER}"

    cat > ${TEMP_FILE} <<-EOF
    [
      {
        "name": "${PINGDATA_EXT_ARTIFACT_NAME}",
        "version": "${PINGDATA_EXT_ARTIFACT_VERSION}",
        "filename": "${PINGDATA_EXT_ARTIFACT_FILENAME}"
      }
    ]
EOF

    # Set file to valid artifact.
    set_artifact_list_json_file

    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code_script=${?}

    # Search for artifact plugin in downloaded directory and capture status code.
    kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c \
      "test -f ${TARGET_DIR}/${PINGDATA_EXT_ARTIFACT_FILENAME}" > /dev/null 2>&1
    actual_status_code_artifact_deploy=${?}

    # Return 0 if the actual status code of deploying valid artifacts is equal to the expected.
    assertEquals ${expected_status_code} ${actual_status_code_script}
    assertEquals ${expected_status_code} ${actual_status_code_artifact_deploy}

    REPLICA_INDEX=$((REPLICA_INDEX - 1))
  done
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}