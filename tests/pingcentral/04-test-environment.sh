#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"


if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  ENVIRONMENT_URL="https://pingcentral.${TENANT_DOMAIN}/api/v1/environments"
  ENVIRONMENT_NAME="P1AS_default_environment_${ENV_TYPE}"
  PINGCENTRAL_ENVIRONMENT_VARIABLES_CONFIGMAP=$(kubectl get configmap pingcentral-environment-variables -n ping-cloud -o json)
  PINGCENTRAL_PASSWORDS_SECRET=$(kubectl get secret pingcentral-passwords -n ping-cloud -o json)
  PC_ADMIN_USER_USERNAME=$(printf '%s\n' "${PINGCENTRAL_ENVIRONMENT_VARIABLES_CONFIGMAP}" | jq -r '.data.PC_ADMIN_USER_USERNAME')
  PC_ADMIN_USER_PASSWORD=$(printf '%s\n' "${PINGCENTRAL_PASSWORDS_SECRET}" | jq -r '.data.PC_ADMIN_USER_PASSWORD | @base64d')
  ENVIRONMENT=$(get_environment "${ENVIRONMENT_NAME}")

  echo "PingCentral environments URL: ${ENVIRONMENT_URL}"
  echo "PingCentral environment name: ${ENVIRONMENT_NAME}"
  echo "PingCentral environment: ${ENVIRONMENT}"
}

# get environment json from pingcentral
get_environment() {
  local name="$1"

  response=$(curl -k -u "${PC_ADMIN_USER_USERNAME}:${PC_ADMIN_USER_PASSWORD}" -H 'X-XSRF-Header: PASS' "${ENVIRONMENT_URL}")
  curl_status=$?
  if [ ${curl_status} -ne 0 ]; then
    fail "Failed to connect to PingCentral API at ${ENVIRONMENT_URL}"
  fi
  if ! echo "${response}" | jq empty; then
    fail "Failed to parse response from PingCentral API as JSON. Response: ${response}"
  fi

  environment_json=$(printf '%s\n' "${response}" | jq --arg name "$name" '.items[] | select(.name==$name)')
  if [ -z "${environment_json}" ]; then
    fail "PingCentral environment ${name} not found"
  else
    echo "${environment_json}"
    return 0
  fi
}


testEnvironmentExists() {
  if [ -z "${ENVIRONMENT}" ] || ! echo "${ENVIRONMENT}" | jq empty; then
    fail "PingCentral environment '${ENVIRONMENT_NAME}' does not exist or is not valid JSON"
  fi

  environment_name=$(echo "${ENVIRONMENT}" | jq -r '.name // empty')
  if [ -z "${environment_name}" ]; then
    fail "PingCentral environment '${ENVIRONMENT_NAME}' does not exist"
  fi

  assertEquals "Unable to parse '${ENVIRONMENT_NAME}' from environment '${environment_name}'" "${ENVIRONMENT_NAME}" "${environment_name}"
}

testPFAuthenticationTypeIsOAuth2() {
  pf_authentication_type=$(echo "${ENVIRONMENT}" | jq -r '.pfAuthenticationType')

  assertEquals "PingFederate authentication type is '${pf_authentication_type}', and not OAuth2" "OAuth2" "${pf_authentication_type}"
}

testPAAuthenticationTypeIsOAuth2() {
  pa_authentication_type=$(echo "${ENVIRONMENT}" | jq -r '.paAuthenticationType')

  assertEquals "PingAccess authentication type is '${pa_authentication_type}', and not OAuth2" "OAuth2" "${pa_authentication_type}"
}

shift $#

. ${SHUNIT_PATH}