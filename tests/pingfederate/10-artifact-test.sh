#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi


oneTimeSetUp() {
  readonly PRODUCT_NAME=pingfederate
  readonly AGENTLESS_KIT="pf-agentless-integration-kit"
  readonly AGENTLESS_VERSION="2.0.1"
  readonly AGENTLESS_KIT_JARNAME="pf-reference-id-adapter-${AGENTLESS_VERSION}.jar"
  readonly IK_ARTIFACT_NAME="pf-google-connector"
  readonly IK_ARTIFACT_VERSION="3.1.1"
  readonly IK_ARTIFACT_FILENAME="${IK_ARTIFACT_NAME}-${IK_ARTIFACT_VERSION}-runtime.zip"
  readonly IK_ARTIFACT_JARNAME="pf-google-quickconnection-${IK_ARTIFACT_VERSION}.jar"
  readonly SECOND_IK_ARTIFACT_NAME="pf-slack-connector"
  readonly SECOND_IK_ARTIFACT_VERSION="3.0.2"
  readonly SECOND_IK_ARTIFACT_FILENAME="${SECOND_IK_ARTIFACT_NAME}-${SECOND_IK_ARTIFACT_VERSION}-runtime.zip"
  readonly SECOND_IK_ARTIFACT_JARNAME="pf-slack-quickconnection-${SECOND_IK_ARTIFACT_VERSION}.jar"
  readonly AUTHN_API_SDK_NAME="pf-authn-api-sdk"
  readonly AUTHN_API_SDK_VERSION="1.0.0.57"
  readonly AUTHN_API_SDK_JARNAME="${AUTHN_API_SDK_NAME}-${AUTHN_API_SDK_VERSION}.jar"
  readonly TARGET_DEPLOY_DIR="/opt/out/instance/server/default/deploy"
  readonly TARGET_LIB_DIR="/opt/out/instance/server/default/lib"

  ARTIFACT_JSON_FILE=$(mktemp)
  TEMP_ENV_VAR_FILE=$(mktemp)

  ENGINE_SERVERS=$( kubectl get pod -o name -n "${PING_CLOUD_NAMESPACE}" -l role=${PRODUCT_NAME}-engine | grep ${PRODUCT_NAME} | cut -d/ -f2)

  # Prepend admin server to list of runtime engine servers.
  SERVERS="${PRODUCT_NAME}-admin-0 ${ENGINE_SERVERS}"
}

oneTimeTearDown() {
  unset SERVERS
  unset ENGINE_SERVERS
  unset ARTIFACT_JSON_FILE
  unset TEMP_ENV_VAR_FILE
}


# Helper Methods
set_artifact_list_json_file() {
  kubectl cp ${ARTIFACT_JSON_FILE} "${SERVER}":/opt/staging/artifacts/artifact-list.json  -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}"
}

clear_artifact_list_json_file() {
  cat > ${ARTIFACT_JSON_FILE} <<-EOF
    []
EOF
  set_artifact_list_json_file
}

run_artifact_script() {
  # Set PING_ARTIFACT_REPO_URL to "s3://ci-cd-artifacts-bucket" before running artifact script.
  # This bucket will always maintain the custom plugins to execute test.
  kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c \
    "PING_ARTIFACT_REPO_URL=s3://ci-cd-artifacts-bucket; \
    /opt/staging/hooks/10-download-artifact.sh" > /dev/null 2>&1
  return ${?}
}

cleanup_artifacts() {
  kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c \
    "rm ${TARGET_DEPLOY_DIR}/${IK_ARTIFACT_JARNAME}" > /dev/null 2>&1

  kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c \
    "rm ${TARGET_DEPLOY_DIR}/${SECOND_IK_ARTIFACT_JARNAME}" > /dev/null 2>&1
}


# Test Methods

# Validate a valid artifact specified in artifact-list.json is deployed
# Script is expected to deploy the artifact and exit with the non-status code 0.
testDeployValidArtifactInArtifactListJSON() {
  local expected_status_code=0
  local actual_status_code_script=
  local actual_status_code_artifact_deploy=

  log "Test valid artifact deployment in artifact-list.json"

  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" = "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"
    cat > ${ARTIFACT_JSON_FILE} <<-EOF
    [
      {
        "name": "${IK_ARTIFACT_NAME}",
        "version": "${IK_ARTIFACT_VERSION}"
      }
    ]
EOF

  cleanup_artifacts

  set_artifact_list_json_file
  run_artifact_script
  actual_status_code_script=${?}

  # Search for artifact plugin in /deploy directory and capture status code.
  kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c \
    "test -f ${TARGET_DEPLOY_DIR}/${IK_ARTIFACT_JARNAME}" > /dev/null 2>&1
  actual_status_code_artifact_deploy=${?}

  assertEquals "Artifact deploy script did not return expected value." ${expected_status_code} ${actual_status_code_script}
  assertEquals "Expected artifact ${IK_ARTIFACT_JARNAME} was not deployed succesfully." ${expected_status_code} ${actual_status_code_artifact_deploy}

  done
}

# Test when duplicate artifacts are specified in artifact-list.json
# Script is expected to terminate and exit with the error code 1.
testDuplicateArtifactsInArtifactListJSON() {
  local expected_status_code=1
  local actual_status_code=

  log "Test duplicate artifacts in artifact-list.json"
  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" = "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"

    cat > ${ARTIFACT_JSON_FILE} <<-EOF
    [
      {
        "name": "${IK_ARTIFACT_NAME}",
        "version": "${IK_ARTIFACT_VERSION}"
      },
      {
        "name": "${IK_ARTIFACT_NAME}",
        "version": "${IK_ARTIFACT_VERSION}"
      }
    ]
EOF

    set_artifact_list_json_file

    run_artifact_script
    actual_status_code=${?}

    assertEquals "Artifact deploy script did not terminate as expected." ${expected_status_code} ${actual_status_code}

  done
}

# Test when the artifact JSON is missing artifact name
# Script is expected to terminate and exit with the error code 1.
testMissingArtifactName() {
  local expected_status_code=1
  local actual_status_code=

  log "Test missing artifact name in JSON"
  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" = "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"
    cat > ${ARTIFACT_JSON_FILE} <<-EOF
    [
      {
        "version": "${IK_ARTIFACT_VERSION}"
      }
    ]
EOF

    set_artifact_list_json_file

    run_artifact_script
    actual_status_code=${?}

    assertEquals "Artifact deploy script did not terminate as expected." ${expected_status_code} ${actual_status_code}

  done
}

# Test when the artifact JSON is missing artifact name
# Script is expected to terminate and exit with the error code 1.
testMissingArtifactVersion() {
  local expected_status_code=1
  local actual_status_code=

  log "Test missing artifact version in JSON"

  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" = "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"
    cat > ${ARTIFACT_JSON_FILE} <<-EOF
    [
      {
        "name": "${IK_ARTIFACT_NAME}"
      }
    ]
EOF

    set_artifact_list_json_file

    run_artifact_script
    actual_status_code=${?}

    assertEquals "Artifact deploy script did not terminate as expected." ${expected_status_code} ${actual_status_code}

  done
}


# Test when multiple authn-api-sdk jars are deployed
# Script is expected to remove all but the most recent version and exit with non-status code 0.
testMultipleAuthnAPISDKJars() {
  local expected_status_code=0
  local actual_status_code=
  local num_pf_authn_api_sdk_jars=

  log "Test deploying multiple pf-authn-api-sdk jars"

  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" = "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"
    cat > ${ARTIFACT_JSON_FILE} <<-EOF
    [
      {
        "name": "${IK_ARTIFACT_NAME}",
        "version": "${IK_ARTIFACT_VERSION}"
      },
       {
        "name": "${AUTHN_API_SDK_NAME}",
        "version": "${AUTHN_API_SDK_VERSION}"
      }
    ]
EOF

  cleanup_artifacts

  set_artifact_list_json_file

  run_artifact_script
  actual_status_code_script=${?}

  assertEquals "Artifact deploy script did not return expected value." ${expected_status_code} ${actual_status_code_script}

  # Verify there is only one authn-api-sdk jar in /lib
  num_pf_authn_api_sdk_jars=$(kubectl exec ${SERVER} -n "${PING_CLOUD_NAMESPACE}" -c "${CONTAINER}" -- sh -c \
    "ls ${TARGET_LIB_DIR}/${AUTHN_API_SDK_NAME}* | wc -l")

  assertEquals "Number of pf-authn-api-sdk jars in /lib did not match the expected." 1 ${num_pf_authn_api_sdk_jars}

  done
}

# Test when both artifact-list.json is empty
# Script is expected to ignore JSON and exit with the non-status code 0.
testEmptyArtifactListJSON() {
  local expected_status_code=0
  local actual_status_code=

  log "Test empty artifact-list.json"

  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" = "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"

    clear_artifact_list_json_file

    # Run artifact script and capture actual status code from script.
    run_artifact_script
    actual_status_code=${?}

    assertEquals "Artifact deploy script did not return expected value." ${expected_status_code} ${actual_status_code}

  done
}

# Test when the artifact JSON is invalid.
# Script is expected to terminate and exit with the error code 1.
testInvalidArtifactListJson() {
  local expected_status_code=1
  local actual_status_code=

  log "Test invalid artifact_list JSON"
  for SERVER in ${SERVERS}; do

    # Set the container name.
    test "${SERVER}" = "${PRODUCT_NAME}-admin-0" && CONTAINER="${PRODUCT_NAME}-admin" || CONTAINER="${PRODUCT_NAME}"
    cat > ${ARTIFACT_JSON_FILE} <<-EOF
    [
      {{
        "version": "${IK_ARTIFACT_VERSION}"
      }
    ]
EOF

    set_artifact_list_json_file

    run_artifact_script
    actual_status_code=${?}

    assertEquals "Artifact deploy script did not terminate as expected." ${expected_status_code} ${actual_status_code}

  done
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
