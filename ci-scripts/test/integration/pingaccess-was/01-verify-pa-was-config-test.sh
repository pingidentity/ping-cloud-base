#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {

  # Using the pa-test-utils in the pingaccess
  # directory to avoid duplication.
  . ${PROJECT_DIR}/ci-scripts/test/integration/pingaccess/util/pa-test-utils.sh

  SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
  . ${SCRIPT_HOME}/common-api/get-entity-operations.sh

  export PA_ADMIN_PASSWORD=2FederateM0re
}

testWebSession() {
  response=$(get_web_session "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "10")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'P14C Session' "$(strip_double_quotes "${name}")"
}

testPaSite() {
  response=$(get_site "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "10")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'PingAccess Admin Console' "$(strip_double_quotes "${name}")"
}

testPfSite() {
  response=$(get_site "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "20")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'PingFederate Admin Console' "$(strip_double_quotes "${name}")"
}

testKibanaSite() {
  response=$(get_site "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "21")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'Kibana' "$(strip_double_quotes "${name}")"
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

testKibanaVirtualHost() {
  response=$(get_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "21")
  assertEquals "Response value was ${response}" 0 $?

  host=$(parse_value_from_response "${response}" 'host')
  stripped_host=$(strip_double_quotes "${host}")

  if [[ ${stripped_host} =~ ^logs.* ]]; then
    assertContains "${stripped_host}" 'logs'
  else
    fail 'The Kibana virtual host should have a host value starting with logs'
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
  response=$(get_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "10")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'PingAccess App' "$(strip_double_quotes "${name}")"
}

testPfApplication() {
  response=$(get_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "20")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'PingFederate App' "$(strip_double_quotes "${name}")"
}

testKibanaApplication() {
  response=$(get_application "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "21")
  assertEquals "Response value was ${response}" 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals "Name value was ${name}" 'Kibana App' "$(strip_double_quotes "${name}")"
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

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
