#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testUrls "${LOGS_CONSOLE}" "${PROMETHEUS}" "${GRAFANA}"
exit ${?}