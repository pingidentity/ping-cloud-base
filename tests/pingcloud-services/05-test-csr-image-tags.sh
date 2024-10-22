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
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    echo "Skipping testPingAccessImageTag as ENV_TYPE is customer-hub"
    return
  fi
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
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    echo "Skipping testPingFederateImageTag as ENV_TYPE is customer-hub"
    return
  fi
  $(test "${PINGFEDERATE_IMAGE_TAG}")
  assertEquals "PINGFEDERATE_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "pingfederate")
  assertEquals "PingFederate is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${PINGFEDERATE_IMAGE_TAG}" "pingfederate")
  assertEquals "PingFederate CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

#testPingDirectoryImageTag() {
#  if [ "${ENV_TYPE}" == "customer-hub" ]; then
#    echo "Skipping testPingDirectoryImageTag as ENV_TYPE is customer-hub"
#    return
#  fi
#  $(test "${PINGDIRECTORY_IMAGE_TAG}")
#  assertEquals "PINGDIRECTORY_IMAGE_TAG missing from env_vars file" 0 $?

#   unique_count=$(getUniqueTagCount "pingdirectory")
#   assertEquals "PingDirectory is using multiple image tag versions" 1 "${unique_count}"

#   matched_count=$(getMatchedTagCount "${PINGDIRECTORY_IMAGE_TAG}" "pingdirectory")
#   assertEquals "PingDirectory CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
# }

testPingDelegatorImageTag() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    echo "Skipping testPingDelegatorImageTag as ENV_TYPE is customer-hub"
    return
  fi
  $(test "${PINGDELEGATOR_IMAGE_TAG}")
  assertEquals "PINGDELEGATOR_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "pingdelegator")
  assertEquals "PingDelegator is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${PINGDELEGATOR_IMAGE_TAG}" "pingdelegator")
  assertEquals "PingDelegator CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

testPingCentralImageTag() {
  if [ $ENV_TYPE = 'customer-hub' ] || { [[ $CLUSTER_NAME == ci-cd* ]] && [ "${ENV_TYPE}" == "dev" ] && [ "${CI_PIPELINE_SOURCE}" != "schedule" ]; }; then
    $(test "${PINGCENTRAL_IMAGE_TAG}")
    assertEquals "PINGCENTRAL_IMAGE_TAG missing from env_vars file" 0 $?

    unique_count=$(getUniqueTagCount "pingcentral")
    assertEquals "PingCentral is using multiple image tag versions" 1 "${unique_count}"

    matched_count=$(getMatchedTagCount "${PINGCENTRAL_IMAGE_TAG}" "pingcentral")
    assertEquals "PingCentral CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
  else
    log "Detected CDE deploy that does not contain PingCentral.  Skipping test"
  fi
}

testMetadataImageTag() {
  unique_count=$(getUniqueTagCount "metadata")
  assertEquals "PingCloud Metadata is using multiple image tag versions" 1 "${unique_count}"
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
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    echo "Skipping testP14CIntegrationImageTag as ENV_TYPE is customer-hub"
    return
  fi
  $(test "${P14C_INTEGRATION_IMAGE_TAG}")
  assertEquals "P14C_INTEGRATION_IMAGE_TAG missing from env_vars file" 0 $?

  unique_count=$(getUniqueTagCount "p14c-integration")
  assertEquals "P14C Integration is using multiple image tag versions" 1 "${unique_count}"

  matched_count=$(getMatchedTagCount "${P14C_INTEGRATION_IMAGE_TAG}" "p14c-integration")
  assertEquals "P14C Integration CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
}

testLogstashImageTag() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    echo "Skipping testLogstashImageTag as ENV_TYPE is customer-hub"
    return
  fi
  $(test "${LOGSTASH_IMAGE_TAG}")
  assertEquals "LOGSTASH_IMAGE_TAG missing from env_vars file" 0 $?

  local logstashImage=$(kubectl get pod -n elastic-stack-logging logstash-elastic-0 -o jsonpath='{.spec.containers[?(@.name=="logstash")].image}' | awk -F: '{print $2}')
  assertEquals "logstash CSR image tag doesn't match Beluga default image tag" "${LOGSTASH_IMAGE_TAG}" "${logstashImage}" 
  # unique_count=$(getUniqueTagCount "logstash")
  # assertEquals "Logstash is using multiple image tag versions" 1 "${unique_count}"

  # matched_count=$(getMatchedTagCount "${LOGSTASH_IMAGE_TAG}" "logstash")
  # assertEquals "logstash CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
  # Uncomment when https://pingidentity.atlassian.net/browse/PDO-8803 is resolved
}

testOpensearchBootstrapImageTag() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    echo "Skipping testOpensearchBootstrapImageTag as ENV_TYPE is customer-hub"
    return
  fi
  $(test "${OPENSEARCH_BOOTSTRAP_IMAGE_TAG}")
  assertEquals "OPENSEARCH_BOOTSTRAP_IMAGE_TAG missing from env_vars file" 0 $?

  local osBootstrapImage=$(kubectl get pods -n elastic-stack-logging -l job-name=opensearch-bootstrap -o jsonpath='{.items[*].spec.containers[*].image}' | awk -F: '{print $2}')
  assertEquals "os-bootstrap CSR image tag doesn't match Beluga default image tag" "${OPENSEARCH_BOOTSTRAP_IMAGE_TAG}" "${osBootstrapImage}" 
  # unique_count=$(getUniqueTagCount "os-bootstrap")
  # assertEquals "OpensearchBootstrap is using multiple image tag versions" 1 "${unique_count}"

  # matched_count=$(getMatchedTagCount "${OPENSEARCH_BOOTSTRAP_IMAGE_TAG}" "os-bootstrap")
  # assertEquals "os-bootstrap CSR image tag doesn't match Beluga default image tag" 1 "${matched_count}"
  # Uncomment when https://pingidentity.atlassian.net/browse/PDO-8803 is resolved
}
# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}