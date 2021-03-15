#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

export PF_ADMIN_USERNAME="Administrator"
export PF_ADMIN_PASSWORD="2FederateM0re"
export LDAP_DS_ID="LDAP-FA8D375DFAC589A222E13AA059319ABF9823B552"

function make_api_request() {
  set +x
  http_code=$(curl -k -o ${OUT_DIR}/api_response.txt -w "%{http_code}" \
        --retry ${API_RETRY_LIMIT} \
        --max-time ${API_TIMEOUT_WAIT} \
        --retry-delay 1 \
        --retry-connrefused \
        -u ${PF_ADMIN_USER_USERNAME}:${PF_ADMIN_USER_PASSWORD} \
        -H "Content-Type: application/json" \
        -H 'X-Xsrf-Header: PingFederate' "$@")
  curl_result=$?
  "${VERBOSE}" && set -x

  if test "${curl_result}" -ne 0; then
    beluga_error "Admin API connection refused"
    return ${curl_result}
  fi

  if test "${http_code}" -ne 200; then
    beluga_log "API call returned HTTP status code: ${http_code}"
    return 1
  fi

  rm -f ${OUT_DIR}/api_response.txt

  return 0
}

testDataStoreExists() {
  response=$(make_api_request -s -X GET "${PINGFEDERATE_ADMIN_API}/dataStores/${LDAP_DS_ID}") > /dev/null)
  assertEquals "Response value was ${response}" 0 $?
}



