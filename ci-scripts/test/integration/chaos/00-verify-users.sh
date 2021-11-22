#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# test ping-access user
test_ping_user "pingaccess-admin-0" "pingaccess-admin"

# test ping-access-was user
test_ping_user "pingaccess-was-admin-0" "pingaccess-was-admin"

test_ping_user() {
  SERVER="${1}"
  CONTAINER="${2}"

  response=$(kubectl exec "${SERVER}" -c "${CONTAINER}" -n "${NAMESPACE}" -- \
    sh -c "whoami")
    
  if test "${response}" = "ping"; then
    log "Running with ping user"
    success=0

  else
    log "Not Running with ping user"
    success=1
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
