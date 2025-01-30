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

#Function to get the full pod name based on the prefix name 'pingcentral'
get_pod_name() {
  kubectl get pods -n "${PING_CLOUD_NAMESPACE}" --no-headers -o custom-columns=":metadata.name" | grep "^pingcentral" | head -n 1
}

test_valid_perpetual_license() {
  local license_file="pingcentral.lic"
  local container_name="pingcentral"
  local license_dir="/opt/license"
  local temp_file="/tmp/license_test_output.txt"

  pod_name=$(get_pod_name)

  echo "Running integration test for license directory in pod: ${pod_name}"
  kubectl exec -i "${pod_name}" -c $container_name -n "${PING_CLOUD_NAMESPACE}" -- sh -c "ls -a $license_dir" &> $temp_file
  assertEquals "Failed to get contents of ${license_dir}" 0 $?


  grep -q "$license_file" $temp_file
  assertEquals "License file ${license_file} not found in ${license_dir}" 0 $?

}

shift $#

. ${SHUNIT_PATH}


