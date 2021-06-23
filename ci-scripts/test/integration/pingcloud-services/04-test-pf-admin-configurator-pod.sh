#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPingFederateAdminConfiguratorPodStatus() {
  status=$(kubectl get pods --selector=role=pingfederate-admin-configurator -n ${NAMESPACE} -o json | jq -r '.items[].status.phase')
  assertEquals 0 $?
  assertEquals "The status phase of the pingfederate-admin-configurator pod should be Succeeded but was: ${status}" 'Succeeded' ${status}
}

testPingFederateCreatePingOneConnection() {
    connections=$(curl -s -k -u ${PF_ADMIN_USERNAME}:${PF_ADMIN_PASSWORD} \
        -H "Content-Type: application/json" \
        -H 'X-Xsrf-Header: PingFederate' \
        -X GET "${PINGFEDERATE_ADMIN_API}/pingOneConnections")
    name=$(echo ${connections}| jq .items[0].name)
    active=$(echo ${connections}| jq .items[0].active)
    
    assertEquals "PingOne connection name should be PING_ONE_to_PING_FED_DEMO_Gateway but was: ${name}" "PING_ONE_to_PING_FED_DEMO_Gateway" ${name}
    assertEquals "PingOne connection active status should be true but was: ${active}" "true" ${active}
}

testPingFederateConfiguratorLogs() {
    JOB_NAME=pingfederate-admin-configurator
    POD=

    POD=$(kubectl -n "${NAMESPACE}" get pod -l  job-name="${JOB_NAME}" -o json | jq .items[0].metadata.name|sed 's/"//g')
    LOG=$(kubectl -n "${NAMESPACE}" logs "${POD}")
    assertContains "${LOG}" "PING_FED-DEMO_Gateway"
    assertContains "${LOG}" "Gateway credential created successfully, passing to PF"
    assertContains "${LOG}" "Added Demo LDAP Data Store"
    assertContains "${LOG}" "Created LDAP PCV"
    assertContains "${LOG}" "Created Notification Publisher"
    assertContains "${LOG}" "Created HTML form adapter"
    assertContains "${LOG}" "Created PingID adapter"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
