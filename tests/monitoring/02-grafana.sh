#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

GRAFANA_ROLE="X-Webauth-Role: Admin"
GRAFANA_EMAIL="X-Webauth-Email: admin@test.com"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testGrafanaAPIAccessible() {
  curl -k -s ${GRAFANA}/api/health >> /dev/null
  assertEquals "Grafana API is unreacheable. URL: ${GRAFANA}/api/health" 0 $?
}

testGrafanaUnauthorizedAccess() {
  response=$(curl -s -k ${GRAFANA}/api/datasources)
  assertContains "${response}" "Unauthorized"
}

testGrafanaDatasourcesExists() {
  for i in {1..5}
  do
    sources=$(curl -H "${GRAFANA_EMAIL}" -H "${GRAFANA_ROLE}" -s -k ${GRAFANA}/api/datasources | jq '.[].name')
    log "${sources}"

    if [[ -z ${sources} ]] ; then
      log "Waiting for sources sync. This is attempt ${i} of 5. Wait 20 seconds and then try again"
    else
      break
    fi
  done
  
  assertContains "${sources}" "OS-PA-Audit"
  assertContains "${sources}" "OS-PF-Audit"
  assertContains "${sources}" "prometheus"
}

testGrafanaFoldersExist() {
  for i in {1..5}
  do
    folders=$(curl -H "${GRAFANA_EMAIL}" -H "${GRAFANA_ROLE}" -s -k ${GRAFANA}/api/folders | jq '.[].title')

    if [[ -z ${folders} ]] ; then
      log "Waiting for folders sync. This is attempt ${i} of 5. Wait 20 seconds and then try again"
    else
      break
    fi
  done

  assertContains "${folders}" "Kubernetes"
  assertContains "${folders}" "Monitoring"
  assertContains "${folders}" "Ping"
}

testGrafanaFoldersPermissions() {
  for i in {1..5}
  do
    folders=$(curl -H "${GRAFANA_EMAIL}" -H "${GRAFANA_ROLE}" -s -k ${GRAFANA}/api/folders | jq '.[]')

    if [[ -z ${folders} ]] ; then
      log "Waiting for folders sync. This is attempt ${i} of 5. Wait 20 seconds and then try again"
    else
      break
    fi
  done

  ping_uid=$(echo "$folders" | jq -r 'select(.title=="Ping") | .uid')
  monitoring_uid=$(echo "$folders" | jq -r 'select(.title=="Monitoring") | .uid')
  kubernetes_uid=$(echo "$folders" | jq -r 'select(.title=="Kubernetes") | .uid')

  ping_permissions=$(curl -H "${GRAFANA_EMAIL}" -H "${GRAFANA_ROLE}" -s -k ${GRAFANA}/api/folders/${ping_uid}/permissions | jq '.[].role' | wc -l)
  monitoring_permissions=$(curl -H "${GRAFANA_EMAIL}" -H "${GRAFANA_ROLE}" -s -k ${GRAFANA}/api/folders/${monitoring_uid}/permissions | jq '.[].role' | wc -l)
  kubernetes_permissions=$(curl -H "${GRAFANA_EMAIL}" -H "${GRAFANA_ROLE}" -s -k ${GRAFANA}/api/folders/${kubernetes_uid}/permissions | jq '.[].role' | wc -l)

  assertEquals "Ping folder should have 2 permission entry" 2 ${ping_permissions}
  assertEquals "Monitoring folder should have 0 additional permission entry" 0 ${monitoring_permissions}
  assertEquals "Kubernetes folder should have 0 permission entry" 0 ${kubernetes_permissions}
}

testGrafanaDashboardsExist() {
  for i in {1..10}
  do
    dashboards=$(curl -H "${GRAFANA_EMAIL}" -H "${GRAFANA_ROLE}" -s -k "${GRAFANA}/api/search?query=%" | jq .[].title)

    if [[ -z ${dashboards} ]]; then
        log "Waiting for dashboards bootstrap. This is attempt ${i} of 10. Wait 20 seconds and then try again"
        sleep 20
    else
        break
    fi
  done
  
  assertContains "${dashboards}" "PingAccess Per-Server Dashboard"
  assertContains "${dashboards}" "PingAccess Topology Dashboard"
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
