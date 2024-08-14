#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"
. "${CI_SCRIPTS_DIR}"/test/test_utils.sh

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testUrls() {
  # Remove websession for grafana app
  # Note: Grafana app id is hardcoded in `pingcloud-apps/pingaccess/src/hooks/83-configure-initial-pa-was.sh`
  # Update here if it is changed
  removeWebsession "22"

  # Remove websession for prometheus app
  # Note: Prometheus app id is hardcoded in `pingcloud-apps/pingaccess/src/hooks/83-configure-initial-pa-was.sh`
  # Update here if it is changed
  removeWebsession "23"

  return_code=0
  for i in {1..10}
  do
    testUrlsWithoutBasicAuthExpect2xx ${PROMETHEUS}/api/v1/status/runtimeinfo ${GRAFANA}/api/health
    return_code=$?
    if [[ ${return_code} -ne 0 ]]; then
      log "Monitoring endpoints are inaccessible.  This is attempt ${i} of 10.  Wait 60 seconds and then try again..."
      sleep 60
    else
      break
    fi
  done

  assertEquals "Failed to connect to the Monitoring URLs: ${PROMETHEUS}/api/v1/status/runtimeinfo ${GRAFANA}/api/health" 0 ${return_code}
}

removeWebsession() {
  local app_id="${1}"

  # Get app current config
  app_config=$(curl -k -s --retry 10 -u "Administrator:${ADMIN_PASS}" -H 'X-Xsrf-Header: PingAccess' \
                "${PINGACCESS_WAS_API}/applications/${app_id}")

  if ! grep -q 'webSessionId' <<< "${app_config}"; then
    log "Could not remove auth from URLs"
    log "webSessionId not found in app config: ${app_config}"
    return 1
  fi

  # Remove websession from app config
  app_config=$(jq -n "${app_config}" | jq '.webSessionId = 0')

  # Update app config
  curl -s -k -X PUT -d "${app_config}" -u "Administrator:${ADMIN_PASS}" \
      -H 'X-Xsrf-Header: PingAccess' \
      "${PINGACCESS_WAS_API}/applications/${app_id}" -o /dev/null 2>/dev/null
  curl_result=$?
  if test "${curl_result}" -ne 0; then
    log "Admin API connection refused with the curl exit code: ${curl_result}"
    return 1
  fi

  # sleep 10 seconds to allow the app to update
  sleep 10
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
