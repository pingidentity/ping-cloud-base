#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testGrafanaAPIAccessible() {
  curl -k -s ${GRAFANA}/api/health >> /dev/null
  assertEquals "Grafana API is unreacheable. URL: ${GRAFANA}/api/health" 0 $?
}

testGrafanaDatasourcesExists() {
  sources=$(curl -s -k ${GRAFANA}/api/datasources | jq .[].name)
  
  assertContains "${sources}" "ES-PA-Admin-Audit"
  assertContains "${sources}" "ES-PA-Audit"
  assertContains "${sources}" "ES-PA-Admin-System"
  assertContains "${sources}" "ES-PF-Admin-Audit"
  assertContains "${sources}" "ES-PF-Audit"
  assertContains "${sources}" "ES-PF-Admin-System"
  assertContains "${sources}" "prometheus"
}

testGrafanaDashboardsExist() {
  
  for i in {1..10}
  do
    dashboards=$(curl -s -k "${GRAFANA}/api/search?query=%" | jq .[].title)

    if [[ -z ${dashboards} ]]; then
        log "Waiting for dashboards bootstrap. This is attempt ${i} of 10. Wait 20 seconds and then try again"
        sleep 20
    else
        break
    fi
  done
  
  assertContains "${dashboards}" "PingAccess Per-Server Dashboard"
  assertContains "${dashboards}" "PingAccess Topology Dasboard"
  assertContains "${dashboards}" "PingDirectory Per-Server Dashboard"
  assertContains "${dashboards}" "PingDirectory Topology Dashboard"
  assertContains "${dashboards}" "PingFederate Per-Server Dashboard"
  assertContains "${dashboards}" "PingFederate Topology Dashboard"
  assertContains "${dashboards}" "Kubernetes Cluster Monitoring"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
