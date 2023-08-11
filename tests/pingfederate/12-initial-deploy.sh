#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

export PF_ADMIN_POD_NAME="pingfederate-admin-0"

# The following test verifies that PF Admin deploys successfully without any restarts
testPFAdminInitialDeployHappyPath() {

  pf_admin_pod_info=$( kubectl get pods ${PF_ADMIN_POD_NAME} -n "${PING_CLOUD_NAMESPACE}" )
  pf_admin_status=$(echo "${pf_admin_pod_info}" | awk 'NR!=1 {print $3}' | tr -d '[:space:]' )
  assertEquals "Running" "${pf_admin_status}"

  pf_admin_restart_count=$(echo "${pf_admin_pod_info}" | awk 'NR!=1 {print $4}' | tr -d '[:space:]' )
  assertEquals 0 ${pf_admin_restart_count}
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}