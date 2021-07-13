#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

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
  echo "${RETURN_VAL}" | jq -r '.[] [].image' | grep -v 'N/A' > "${TEMP_FILE_METADATA}"
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

  unique_count=$(getUniqueTagCount "pingaccess")
  assertEquals "PingAccess is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${PINGACCESS_IMAGE_TAG}" "pingaccess")
  assertEquals "PingAccess CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
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
  $(test "${PINGCENTRAL_IMAGE_TAGE}")
  assertEquals "PINGCENTRAL_IMAGE_TAGE missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "pingcentral")
  assertEquals "PingCentral is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${PINGCENTRAL_IMAGE_TAGE}" "pingcentral")
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

testP14CBootstrapImageTag() {
  $(test "${P14C_BOOTSTRAP_IMAGE_TAG}")
  assertEquals "P14C_BOOTSTRAP_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "p14c-bootstrap")
  assertEquals "P14C Bootstrap is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${P14C_BOOTSTRAP_IMAGE_TAG}" "p14c-bootstrap")
  assertEquals "P14C Bootstrap CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

testP14CIntegrationImageTag() {
  $(test "${P14C_INTEGRATION_IMAGE_TAG}")
  assertEquals "P14C_INTEGRATION_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "p14c-integration")
  assertEquals "P14C Integration is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${P14C_INTEGRATION_IMAGE_TAG}" "p14c-integration")
  assertEquals "P14C Integration CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}