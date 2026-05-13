#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# test ping access admin user
test_ping_user_pa_admin() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi

  verify_ping_user "pingaccess-admin-0" "pingaccess-admin"

}

# test ping access engine user
test_ping_user_pa_engine() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi

  # test pingaccess-0 server
  verify_ping_user "pingaccess-0" "pingaccess"

  # test pingaccess-1 server
  verify_ping_user "pingaccess-1" "pingaccess"

}

# test ping access was admin user
test_ping_user_pa_was_admin() {

  verify_ping_user "pingaccess-was-admin-0" "pingaccess-was-admin"

}

# test ping access was engine user
test_ping_user_pa_was_engine() {
 
  # test pingaccess-was-0 server
  verify_ping_user "pingaccess-was-0" "pingaccess-was"

}

# test ping federate admin user
test_ping_user_pf_admin() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi  

  verify_ping_user "pingfederate-admin-0" "pingfederate-admin"

}

# test ping federate engine user
test_ping_user_pf_engine() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi  
 
  # test pingfederate-0 server
  verify_ping_user "pingfederate-0" "pingfederate"

  # test pingfederate-1 server
  verify_ping_user "pingfederate-1" "pingfederate"

}

# test ping directory user
test_ping_user_pd() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi  
  
  # test pingdirectory-0 server
  verify_ping_user "pingdirectory-0" "pingdirectory"

  # test pingdirectory-1 server
  verify_ping_user "pingdirectory-1" "pingdirectory"

}

# test ping delegator user
test_ping_user_pdel() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi

  # get pingdelegator pod name
  pingdelegator_pods=$(kubectl get pod -n "${PING_CLOUD_NAMESPACE}" --field-selector=status.phase=Running --no-headers -o custom-columns=":metadata.name"  | grep pingdelegator)

  # test pingdelegator server
  for pingdelegator_pod in ${pingdelegator_pods}; do
    verify_ping_user "${pingdelegator_pod}" "pingdelegator"
  done

  }

# test ping central user
test_ping_user_pc() {
  
  # get pingcentral pod name
  pingcentral_pods=$(kubectl get pod -n "${PING_CLOUD_NAMESPACE}" --field-selector=status.phase=Running --no-headers -o custom-columns=":metadata.name"  | grep pingcentral)

  # test pingcentral server
  for pingcentral_pod in ${pingcentral_pods}; do
    verify_ping_user "${pingcentral_pod}" "pingcentral"
  done

  }

  # test ping datasync user
test_ping_user_pds() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi  
  
  # get pingdatasync pod name
  pingdatasync_pods=$(kubectl get pod -n "${PING_CLOUD_NAMESPACE}" --field-selector=status.phase=Running --no-headers -o custom-columns=":metadata.name"  | grep pingdatasync)

  # test pingdatasync server
  for pingdatasync_pod in ${pingdatasync_pods}; do
    verify_ping_user "${pingdatasync_pod}" "pingdatasync"
  done

  }

verify_ping_user() {
  SERVER="${1}"
  CONTAINER="${2}"

  response=$(kubectl exec "${SERVER}" -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}" -- \
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