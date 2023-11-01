#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  . "${PROJECT_DIR}"/code-gen/templates/common/base/env_vars

  log "Query endpoint: ${PINGCLOUD_METADATA_API}"
  RETURN_VAL=$(curl -s -m 5 -k -L "${PINGCLOUD_METADATA_API}")
  assertEquals "Failed to connect to: ${PINGCLOUD_METADATA_API}" 0 $?

  TEMP_FILE_METADATA="$(mktemp)"
  echo "${RETURN_VAL}" | jq -r '.version [].image' | grep -v 'N/A' > "${TEMP_FILE_METADATA}"
}

getUniqueTagCount() {
  pod_name="${1}"
  echo $(cat "${TEMP_FILE_METADATA}" | grep ${pod_name} | sort -u | wc -l | awk '{ print $1 }')
}

getMatchedTagCount() {
  image_tag_name="${1}"
  pod_name="${2}"
  echo $(cat "${TEMP_FILE_METADATA}" | grep ${pod_name} | sort -u \
        | grep ${image_tag_name} | wc -l | awk '{ print $1 }')
}

testPingAccessImageTag() {
  $(test "${PINGACCESS_IMAGE_TAG}")
  assertEquals "PINGACCESS_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(echo "${RETURN_VAL}" \
                | jq '.version | with_entries( select(.key|contains("pingaccess") ) )' \
                | jq '. | with_entries( select(.key|contains("pingaccess-was") | not) )| .[].image' \
                | sort -u | grep "pingaccess" | wc -l | awk '{ print $1 }')
  assertEquals "PingAccess is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(echo "${RETURN_VAL}" \
                | jq '.version | with_entries( select(.key|contains("pingaccess") ) )' \
                | jq '. | with_entries( select(.key|contains("pingaccess-was") | not) ) | .[].image' \
                | sort -u | grep "pingaccess" | grep ${PINGACCESS_IMAGE_TAG} |  wc -l | awk '{ print $1 }')
  assertEquals "PingAccess CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

testPingAccessWASImageTag() {
  $(test "${PINGACCESS_WAS_IMAGE_TAG}")
  assertEquals "PINGACCESS_WAS_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(echo "${RETURN_VAL}" \
                | jq '.version | with_entries( select( .key|contains("pingaccess-was") ) ) | .[].image' \
                | sort -u | grep "pingaccess" | wc -l | awk '{ print $1 }')
  assertEquals "PingAccess WAS is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(echo "${RETURN_VAL}" \
                | jq '.version | with_entries( select( .key|contains("pingaccess-was") ) ) | .[].image' \
                | sort -u | grep "pingaccess" | grep ${PINGACCESS_WAS_IMAGE_TAG} | wc -l | awk '{ print $1 }')
  assertEquals "PingAccess WAS CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

testPingFederateImageTag() {
  $(test "${PINGFEDERATE_IMAGE_TAG}")
  assertEquals "PINGFEDERATE_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "pingfederate")
  assertEquals "PingFederate is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${PINGFEDERATE_IMAGE_TAG}" "pingfederate")
  assertEquals "PingFederate CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

testPingDirectoryImageTag() {
  $(test "${PINGDIRECTORY_IMAGE_TAG}")
  assertEquals "PINGDIRECTORY_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "pingdirectory")
  assertEquals "PingDirectory is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${PINGDIRECTORY_IMAGE_TAG}" "pingdirectory")
  assertEquals "PingDirectory CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

testPingDelegatorImageTag() {
  $(test "${PINGDELEGATOR_IMAGE_TAG}")
  assertEquals "PINGDELEGATOR_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "pingdelegator")
  assertEquals "PingDelegator is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${PINGDELEGATOR_IMAGE_TAG}" "pingdelegator")
  assertEquals "PingDelegator CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

testPingCentralImageTag() {
  if [ "${ENV_TYPE}" != "customer-hub" ] && [ "${CI_PIPELINE_SOURCE}" == "schedule" ]; then
    log "Detected CDE deploy that does not contain PingCentral.  Skipping test"
    return 0
  fi
  $(test "${PINGCENTRAL_IMAGE_TAG}")
  assertEquals "PINGCENTRAL_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "pingcentral")
  assertEquals "PingCentral is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${PINGCENTRAL_IMAGE_TAG}" "pingcentral")
  assertEquals "PingCentral CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

testMetadataImageTag() {
  $(test "${METADATA_IMAGE_TAG}")
  assertEquals "METADATA_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "metadata")
  assertEquals "PingCloud Metadata is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${METADATA_IMAGE_TAG}" "metadata")
  assertEquals "PingCloud Metadata CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

testBootstrapImageTag() {
  $(test "${BOOTSTRAP_IMAGE_TAG}")
  assertEquals "BOOTSTRAP_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "bootstrap")
  assertEquals "Bootstrap is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${BOOTSTRAP_IMAGE_TAG}" "bootstrap")
  assertEquals "Bootstrap CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

testP14CIntegrationImageTag() {
  $(test "${P14C_INTEGRATION_IMAGE_TAG}")
  assertEquals "P14C_INTEGRATION_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "p14c-integration")
  assertEquals "P14C Integration is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${P14C_INTEGRATION_IMAGE_TAG}" "p14c-integration")
  assertEquals "P14C Integration CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

testAnsibleBelugaImageTag() {
  $(test "${ANSIBLE_BELUGA_IMAGE_TAG}")
  assertEquals "ANSIBLE_BELUGA_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "ansible-beluga")
  assertEquals "Ansible Beluga is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${ANSIBLE_BELUGA_IMAGE_TAG}" "ansible-beluga")
  assertEquals "Ansible Beluga CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}