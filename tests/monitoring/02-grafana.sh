#!/bin/bash

oneTimeSetUp() {
  CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
  . "${CI_SCRIPTS_DIR}/common.sh" "${1}"

  GRAFANA_ROLE="X-Webauth-Role: Admin"
  GRAFANA_EMAIL="X-Webauth-Email: admin@test.com"

  if skipTest "${0}"; then
    log "Skipping test ${0}"
    exit 0
  fi

  NAMESPACE="${PING_CLOUD_NAMESPACE:-prometheus}"

  if [[ -z "${GRAFANA:-}" || "${GRAFANA}" == "https://monitoring." ]]; then
    if kubectl get svc grafana -n "${NAMESPACE}" &>/dev/null; then
      GRAFANA="http://grafana.${NAMESPACE}.svc.cluster.local:3000"
    else
      echo "ERROR: GRAFANA not set and grafana service not found"
      exit 1
    fi
  fi
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

testGrafanaDashboardsExist() {
  for i in {1..10}; do
    dashboards=$(curl -H "${GRAFANA_EMAIL}" -H "${GRAFANA_ROLE}" -s -k "${GRAFANA}/api/search?query=%" | jq .[].title)

    if [[ -z ${dashboards} ]]; then
      log "Waiting for dashboards bootstrap. This is attempt ${i} of 10. Wait 20 seconds and then try again"
      sleep 20
    else
      break
    fi
  done

  assertContains "${dashboards}" "Kubernetes Cluster Monitoring"

  if [ "${ENV_TYPE}" == "customer-hub" ]; then
    return
  fi

  assertContains "${dashboards}" "PingAccess Per-Server Dashboard"
  assertContains "${dashboards}" "PingAccess Topology Dashboard"
  assertContains "${dashboards}" "PingDirectory Per-Server Dashboard"
  assertContains "${dashboards}" "PingDirectory Topology Dashboard"
  assertContains "${dashboards}" "PingFederate Per-Server Dashboard"
  assertContains "${dashboards}" "PingFederate Topology Dashboard"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
