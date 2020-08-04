#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

setUp() {

  # Using the pa-test-utils in the pingaccess
  # directory to avoid duplication.
  . ${PROJECT_DIR}/ci-scripts/test/integration/pingaccess/util/pa-test-utils

  SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
  . ${SCRIPT_HOME}/common-api/get-entity-operations

  export PA_ADMIN_PASSWORD=2FederateM0re
}

testKibanaSite() {

  response=$(get_site "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "21")
  assertEquals 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals 'Kibana' $(strip_double_quotes ${name})
}

testGrafanaSite() {

  response=$(get_site "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "22")
  assertEquals 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals 'Grafana' $(strip_double_quotes ${name})
}

testPrometheusSite() {

  response=$(get_site "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "23")
  assertEquals 0 $?

  name=$(parse_value_from_response "${response}" 'name')
  assertEquals 'Prometheus' $(strip_double_quotes ${name})
}

testKibanaVirtualHost() {
  response=$(get_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "21")
  assertEquals 0 $?

  host=$(parse_value_from_response "${response}" 'host')
  stripped_host=$(strip_double_quotes ${host})

  if [[ ${stripped_host} =~ ^logs.* ]]; then
    assertContains ${stripped_host} 'logs'
  else
    fail 'The Kibana virtual host should have a host value starting with logs'
  fi
}

testGrafanaVirtualHost() {
  response=$(get_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "22")
  assertEquals 0 $?

  host=$(parse_value_from_response "${response}" 'host')
  stripped_host=$(strip_double_quotes ${host})

  if [[ ${stripped_host} =~ ^monitoring.* ]]; then
    assertContains ${stripped_host} 'monitoring'
  else
    fail 'The Grafana virtual host should have a host value starting with monitoring'
  fi
}

testPrometheusVirtualHost() {
  response=$(get_virtual_host "${PA_ADMIN_PASSWORD}" "${PINGACCESS_WAS_API}" "23")
  assertEquals 0 $?

  host=$(parse_value_from_response "${response}" 'host')
  stripped_host=$(strip_double_quotes ${host})

  if [[ ${stripped_host} =~ ^prometheus.* ]]; then
    assertContains ${stripped_host} 'prometheus'
  else
    fail 'The Prometheus virtual host should have a host value starting with prometheus'
  fi
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}