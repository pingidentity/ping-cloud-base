#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

NERDGRAPH_ENDPOINT="https://api.newrelic.com/graphql"

NEW_RELIC_API_KEY=$(get_ssm_val "/pcpt/sre/new-relic/api-query-key")
NEW_RELIC_ACCOUNT_ID=$(get_ssm_val "/pcpt/sre/new-relic/validation-acct-id")
CLUSTER_NAME="${TENANT_NAME}_${ENV_TYPE}_${REGION}_k8s-cluster"
NAMESPACE="newrelic"

log "Using CLUSTER_NAME: ${CLUSTER_NAME}"

testKubeletPodAndLog() {
  POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/instance=nri-bundle,app.kubernetes.io/component=kubelet" \
    -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')
  assertNotNull "No running Kubelet pods found in namespace '${NAMESPACE}'." "${POD_NAME}"
  log "Found running pod: ${POD_NAME} in namespace '${NAMESPACE}'."

  LOGS=$(kubectl logs -n "${NAMESPACE}" "${POD_NAME}" -c kubelet --tail=100)
  EXPECTED_MESSAGE="Connected to Kubelet through nodeIP with scheme"
  assertContains "Expected log message '${EXPECTED_MESSAGE}' not found in the kubelet pod logs for pod '${POD_NAME}'." \
    "${LOGS}" "${EXPECTED_MESSAGE}"
  log "Verified log message in pod: ${POD_NAME}."
}

testMetricsQuery() {
  RESPONSE=$(curl -s -X POST "${NERDGRAPH_ENDPOINT}" \
      -H "Content-Type: application/json" \
      -H "API-Key: ${NEW_RELIC_API_KEY}" \
      -d @- <<EOF
{
  "query": "{
    actor {
      account(id: ${NEW_RELIC_ACCOUNT_ID}) {
        nrql(query: \\"SELECT average(cpuPercent) AS cpuUsage, average(memoryUsedPercent) AS memoryUsage FROM SystemSample WHERE \`clusterName\` = '${CLUSTER_NAME}' SINCE 15 minutes ago\\") {
          results
        }
      }
    }
  }"
}
EOF
  )

  log "Full API Response: ${RESPONSE}"

  CPU_USAGE=$(echo "${RESPONSE}" | jq -r '.data.actor.account.nrql.results[0].cpuUsage')
  MEMORY_USAGE=$(echo "${RESPONSE}" | jq -r '.data.actor.account.nrql.results[0].memoryUsage')

  assertNotNull "Metrics query returned null CPU usage." "${CPU_USAGE}"
  assertNotNull "Metrics query returned null Memory usage." "${MEMORY_USAGE}"
  assertTrue "Metrics query returned 0 or less CPU usage." "[[ ${CPU_USAGE} > 0 ]]"
  assertTrue "Metrics query returned 0 or less Memory usage." "[[ ${MEMORY_USAGE} > 0 ]]"
 
  log "Metrics query successful. CPU Usage: ${CPU_USAGE}, Memory Usage: ${MEMORY_USAGE}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
