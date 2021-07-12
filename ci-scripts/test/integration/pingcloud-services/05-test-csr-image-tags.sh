#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testCSRImageTagMatchesBelugaDefaultImage() {
  . "${PROJECT_DIR}"/code-gen/templates/common/base/env_vars

  $(test "${PINGACCESS_IMAGE_TAG}" && \
    test "${PINGFEDERATE_IMAGE_TAG}" && \
    test "${PINGDIRECTORY_IMAGE_TAG}" && \
    test "${PINGDELEGATOR_IMAGE_TAG}")
  assertEquals "One of the required image tags missing from env_vars file" 0 $?

  log "Query endpoint: ${PINGCLOUD_METADATA_API}"
  RETURN_VAL=$(curl -s -m 5 -k -L "${PINGCLOUD_METADATA_API}")
  assertEquals "Failed to connect to: ${PINGCLOUD_METADATA_API}" 0 $?

  temp_file_metadata="$(mktemp)"
  echo "${RETURN_VAL}" | jq -r '.[] [].image' | grep -v 'N/A' > "${temp_file_metadata}"

  # Test PA image tag
  uniqueTagCount=$(cat "${temp_file_metadata}" | grep "pingaccess" | sort -u | wc -l | awk '{ print $1 }')
  assertEquals "PingAccess is using multiple image tag versions" 1 "${uniqueTagCount}"

  matchedTagCount=$(cat "${temp_file_metadata}" | grep "pingaccess" | sort -u \
                    | grep "${PINGACCESS_IMAGE_TAG}" | wc -l | awk '{ print $1 }')
  assertEquals "PingAccess CSR image tag doesn't match Beluga default image tag" 1 "${matchedTagCount}"

  # Test PF image tag
  uniqueTagCount=$(cat "${temp_file_metadata}" | grep "pingfederate" | sort -u | wc -l | awk '{ print $1 }')
  assertEquals "PingFederate is using multiple image tag versions" 1 "${uniqueTagCount}"

  matchedTagCount=$(cat "${temp_file_metadata}" | grep "pingfederate" | sort -u \
                    | grep "${PINGFEDERATE_IMAGE_TAG}" | wc -l | awk '{ print $1 }')
  assertEquals "PingFederate CSR image tag doesn't match Beluga default image tag" 1 "${matchedTagCount}"

  # Test PD image tag
  uniqueTagCount=$(cat "${temp_file_metadata}" | grep "pingdirectory" | sort -u | wc -l | awk '{ print $1 }')
  assertEquals "PingDirectory is using multiple image tag versions" 1 "${uniqueTagCount}"

  matchedTagCount=$(cat "${temp_file_metadata}" | grep "pingdirectory" | sort -u \
                    | grep "${PINGDIRECTORY_IMAGE_TAG}" | wc -l | awk '{ print $1 }')
  assertEquals "PingDirectory CSR image tag doesn't match Beluga default image tag" 1 "${matchedTagCount}"

  # Test PingDelegator image tag
  uniqueTagCount=$(cat "${temp_file_metadata}" | grep "pingdelegator" | sort -u | wc -l | awk '{ print $1 }')
  assertEquals "PingDelegator is using multiple image tag versions" 1 "${uniqueTagCount}"

  matchedTagCount=$(cat "${temp_file_metadata}" | grep "pingdelegator" | sort -u \
                    | grep "${PINGDELEGATOR_IMAGE_TAG}" | wc -l | awk '{ print $1 }')
  assertEquals "PingDelegator CSR image tag doesn't match Beluga default image tag" 1 "${matchedTagCount}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}