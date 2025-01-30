#!/bin/bash
########################################################################################################################
# Function: validate_license_file
# Purpose: This function validates whether the specified license file exists within the /opt/license directory in a pod.
#          It checks if the pod is running, verifies the contents of the directory, and checks if the license file
#          is present. It also handles errors and prints appropriate results.
#
# Arguments:
#   ${1} -> The directory name within the pod where the license file is located (i.e., "/opt/license").
#
# Return Values:
#   0 (Success) if the license file is found and all checks pass.
#   1 (Failure) if any of the checks fail.
########################################################################################################################

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"


if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

test_valid_perpetual_license() {
  local license_file="pingaccess.lic"
  local pod_name="pingaccess-admin-0"
  local container_name="pingaccess-admin"
  local license_dir="/opt/license"
  local temp_file="/tmp/license_test_output.txt"

  echo "Running integration test for license directory..."
  kubectl exec -i $pod_name -c $container_name -n "${PING_CLOUD_NAMESPACE}" -- sh -c "ls -a $license_dir" &> $temp_file
  assertEquals "Failed to get contents of ${license_dir}" 0 $?

  grep -q "$license_file" $temp_file
  assertEquals "License file ${license_file} not found in ${license_dir}" 0 $?

}

shift $#

. ${SHUNIT_PATH}


