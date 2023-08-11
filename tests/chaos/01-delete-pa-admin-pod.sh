#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

. "${PROJECT_DIR}"/tests/pingaccess/util/pa-test-utils.sh

testDeletePaAdmin() {

  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi

  PA_ADMIN_PASSWORD=${PA_ADMIN_PASSWORD:-2FederateM0re}

  kubectl delete pod pingaccess-admin-0 -n "${PING_CLOUD_NAMESPACE}"

  log "Waiting for admin server at ${PINGACCESS_API}/applications"

  set +x
  for i in {1..10}
  do
    # Call to a real endpoint to verify
    # PA is up
    response=$(curl -k \
                    -i \
                    -s \
                    -u "Administrator:${PA_ADMIN_PASSWORD}" \
                    -H 'X-Xsrf-Header: PingAccess' \
                    "${PINGACCESS_API}/applications")

    response_code=$(parse_http_response_code "${response}")

    success=1
    if [[ 200 != ${response_code} ]]; then
      log "Admin server not started, waiting.."
      sleep 15
    else
      log "Admin server successfully restarted"
      success=0
      break
    fi
  done

  if [[ ${success} -eq 1 ]]; then
    log "Could not verify the PA admin console came back up after the pod was deleted"
  fi

  assertEquals 0 ${success}
}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
