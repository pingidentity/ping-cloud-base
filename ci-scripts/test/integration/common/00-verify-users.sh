#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# test ping access admin user
test_ping_user_pa_admin() {

  verify_ping_user "pingaccess-admin-0" "pingaccess-admin"

}

# test ping access was admin user
test_ping_user_pa_was_admin() {

  verify_ping_user "pingaccess-was-admin-0" "pingaccess-was-admin"

}

# test ping federate admin user
test_ping_user_pf_admin() {

  verify_ping_user "pingfederate-admin-0" "pingfederate-admin"

}

# test ping directory user
test_ping_user_pd() {
  
  # test pingdirectory-0 server
  verify_ping_user "pingdirectory-0" "pingdirectory"

  # test pingdirectory-1 server
  verify_ping_user "pingdirectory-1" "pingdirectory"

}

verify_ping_user() {
  SERVER="${1}"
  CONTAINER="${2}"

  response=$(kubectl exec "${SERVER}" -c "${CONTAINER}" -n "${NAMESPACE}" -- \
    sh -c "whoami")

  if test "${response}" = "ping"; then
    log "${SERVER} : Running with ping user"
    success=0

  else
    log "${SERVER} Not Running with ping user"
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
