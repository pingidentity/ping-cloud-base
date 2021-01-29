#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPrometheusAPIAccessible() {
  curl -k -s ${PROMETHEUS}/api/v1/status/runtimeinfo >> /dev/null
  assertEquals "Prometheus API is unreacheable. URL: ${PROMETHEUS}/api/v1/status/runtimeinfo" 0 $?
}

testPrometheusTargets() {
  targets=$(curl -s -k ${PROMETHEUS}/api/v1/targets | jq .data.activeTargets[].labels)
  assertContains "${targets}" "pa-heartbeat-exporter"
  assertContains "${targets}" "pa-jmx-exporter"
  assertContains "${targets}" "pf-heartbeat-exporter"
  assertContains "${targets}" "pf-jmx-exporter"
  assertContains "${targets}" "pd-statsd-exporter"
  assertContains "${targets}" "prometheus"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
