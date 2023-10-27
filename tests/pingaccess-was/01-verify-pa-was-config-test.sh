#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"
. "${PROJECT_DIR}"/tests/pingaccess/util/pa-test-utils.sh
. "${PROJECT_DIR}"/tests/pingaccess/common-api/create-entity-operations.sh
. "${PROJECT_DIR}"/tests/pingaccess/common-api/delete-entity-operations.sh
. "${PROJECT_DIR}"/tests/pingaccess-was/common-api/get-entity-operations.sh


if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {

  # Using the pa-test-utils in the pingaccess
  # directory to avoid duplication.
  . ${PROJECT_DIR}/tests/pingaccess/util/pa-test-utils.sh

  SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
  . ${SCRIPT_HOME}/common-api/get-entity-operations.sh

  export PA_ADMIN_PASSWORD=2FederateM0re
  export templates_dir_path="${PROJECT_DIR}"/tests/pingaccess/templates

}

testWebSession() {
  response=$(get_web_session "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "10")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'P14C Session' "$(strip_double_quotes "${name}")"
}

testPaSite() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi
  response=$(get_site "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "10")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'PingAccess Admin Console' "$(strip_double_quotes "${name}")"
}

testPfSite() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi
  response=$(get_site "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "20")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'PingFederate Admin Console' "$(strip_double_quotes "${name}")"
}

testOSDSite() {
  response=$(get_site "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "21")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'OpenSearch Dashboards' "$(strip_double_quotes "${name}")"
}

testGrafanaSite() {
  response=$(get_site "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "22")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'Grafana' "$(strip_double_quotes "${name}")"
}

testPrometheusSite() {
  response=$(get_site "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "23")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'Prometheus' "$(strip_double_quotes "${name}")"
}

testArgocdSite() {
  response=$(get_site "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "24")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'Argo CD' "$(strip_double_quotes "${name}")"
}

testPaVirtualHost() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi
  response=$(get_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "10")
  assertEquals "Response value was ${response}" 0 $?

  host=$(parse_value_from_response "${response}" 'host')
  stripped_host=$(strip_double_quotes "${host}")

  if [[ ${stripped_host} =~ ^pingaccess-admin.* ]]; then
    assertContains "${stripped_host}" 'pingaccess-admin'
  else
    fail 'The PingAccess virtual host should have a host value starting with pingaccess-admin'
  fi
}

testPfVirtualHost() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi
  response=$(get_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "20")
  assertEquals "Response value was ${response}" 0 $?

  host=$(parse_value_from_response "${response}" 'host')
  stripped_host=$(strip_double_quotes "${host}")

  if [[ ${stripped_host} =~ ^pingfederate-admin.* ]]; then
    assertContains "${stripped_host}" 'pingfederate-admin'
  else
    fail 'The PingFederate virtual host should have a host value starting with pingfederate-admin'
  fi
}

testOSDVirtualHost() {
  response=$(get_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "21")
  assertEquals "Response value was ${response}" 0 $?

  host=$(parse_value_from_response "${response}" 'host')
  stripped_host=$(strip_double_quotes "${host}")

  if [[ ${stripped_host} =~ ^logs.* ]]; then
    assertContains "${stripped_host}" 'logs'
  else
    fail 'The OpenSearch Dashboards virtual host should have a host value starting with logs'
  fi
}

testGrafanaVirtualHost() {
  response=$(get_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "22")
  assertEquals "Response value was ${response}" 0 $?

  host=$(parse_value_from_response "${response}" 'host')
  stripped_host=$(strip_double_quotes "${host}")

  if [[ ${stripped_host} =~ ^monitoring.* ]]; then
    assertContains "${stripped_host}" 'monitoring'
  else
    fail 'The Grafana virtual host should have a host value starting with monitoring'
  fi
}

testPrometheusVirtualHost() {
  response=$(get_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "23")
  assertEquals "Response value was ${response}" 0 $?

  host=$(parse_value_from_response "${response}" 'host')
  stripped_host=$(strip_double_quotes "${host}")

  if [[ ${stripped_host} =~ ^prometheus.* ]]; then
    assertContains "${stripped_host}" 'prometheus'
  else
    fail 'The Prometheus virtual host should have a host value starting with prometheus'
  fi
}

testArgocdVirtualHost() {
  response=$(get_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "24")
  assertEquals "Response value was ${response}" 0 $?

  host=$(parse_value_from_response "${response}" 'host')
  stripped_host=$(strip_double_quotes "${host}")

  if [[ ${stripped_host} =~ ^argocd.* ]]; then
    assertContains "${stripped_host}" 'argocd'
  else
    fail 'The Argo CD virtual host should have a host value starting with argocd'
  fi
}

testPaApplication() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi
  response=$(get_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "10")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'PingAccess App' "$(strip_double_quotes "${name}")"
}

testPfApplication() {
  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    log "Customer-hub deployment, skipping test"
    return 0
  fi
  response=$(get_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "20")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'PingFederate App' "$(strip_double_quotes "${name}")"
}

testOSDApplication() {
  response=$(get_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "21")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'OpenSearch Dashboards App' "$(strip_double_quotes "${name}")"
}

testGrafanaApplication() {
  response=$(get_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "22")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'Grafana App' "$(strip_double_quotes "${name}")"
}

testPrometheusApplication() {
  response=$(get_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "23")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'Prometheus App' "$(strip_double_quotes "${name}")"
}

testArgocdApplication() {
  response=$(get_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "24")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'Argo CD App' "$(strip_double_quotes "${name}")"
}

testUpdatedApplicationReservedPath() {
  response=$(get_entity "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}/applications/reserved")
  assertEquals "Response value was ${response}" 0 $?

  context_root=$(parse_value_from_response "${response}" 'contextRoot')
  assertEquals '/pa-was' "$(strip_double_quotes "${context_root}")"
}

testPaWasIdempotent() {
  export APP_ID=123
  export APP_NAME="TestApp"
  export VIRTUAL_HOST_ID=1
  export SITE_ID=24 # SiteID coorelating to ArgoCD.  This will test will create a new application referencing the ArgoCD site.

  # Cleanup from possible previous run failures
  log "Deleting app: ${APP_NAME} if it exists"
  response=$(delete_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "${APP_ID}")

  upload_job="${PROJECT_DIR}"/k8s-configs/ping-cloud/base/pingaccess-was/admin/aws/backup.yaml
  log "Deleting pa-was backup job if it exists"
  kubectl delete -f "${upload_job}" -n "${PING_CLOUD_NAMESPACE}"

  log "Creating new App: ${APP_NAME}"
  response=$(create_site_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}")
  assertEquals "Response value was ${response}" 0 $?

  if [ "${ENV_TYPE}" != "customer-hub" ]; then
    log "Deleting PingAccess App"
    pa_app_id=10
    response=$(delete_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "${pa_app_id}")
    assertEquals "Response value was ${response}" 0 $?
  fi

  log "Backing up PA-WAS"
  kubectl apply -f "${upload_job}" -n "${PING_CLOUD_NAMESPACE}"
  assertEquals "The kubectl apply command to create the PingAccess WAS upload job should have succeeded" 0 $?

  log "Waiting for backup job to complete"
  kubectl wait --for=condition=complete --timeout=900s job/pingaccess-was-backup -n "${PING_CLOUD_NAMESPACE}"
  assertEquals "The kubectl wait command for the backup job should have succeeded" 0 $?

  log "Restarting PA-WAS Admin"
  kubectl exec pingaccess-was-admin-0 -n "${PING_CLOUD_NAMESPACE}" -c pingaccess-was-admin -- sh -c "pgrep -f java | xargs kill"
  sleep 3

  log "Waiting for PA-WAS Admin to be ready"
  kubectl wait --for=condition=ready --timeout=300s pod -l role=pingaccess-was-admin -n "${PING_CLOUD_NAMESPACE}"
  sleep 3

  if [ "${ENV_TYPE}" != "customer-hub" ]; then
    log "Verifying the PingAccess App recreated on restart"
    response=$(get_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "${pa_app_id}")
    assertEquals "The PingAccess App not present after restart: ${response}"  0 $?
  fi

  APP_ID=123 # Unset elsewhere
  log "Verifying the new App: ${APP_NAME} still present"
  response=$(get_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "${APP_ID}")
  assertEquals "The new App: ${APP_NAME} should have been present after restart: ${response}" 0 $?

}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
