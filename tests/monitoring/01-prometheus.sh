#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testPrometheusAPIAccessible() {
  curl -k -s ${PROMETHEUS}/api/v1/status/runtimeinfo >> /dev/null
  assertEquals "Prometheus API is unreacheable. URL: ${PROMETHEUS}/api/v1/status/runtimeinfo" 0 $?
}

# Verify each agent scrape job has active targets with up=1.
# Covers all jobs defined in p1as-prometheus-agent values.yaml for the full PCB stack.
testPrometheusAgentJobsCollectingData() {
  log "Verifying each agent scrape job has active targets via up metric"

  expected_jobs="prometheus kube-state-metrics kubernetes-apiservers kubernetes-nodes kubernetes-pods kubernetes-cadvisor kubernetes-service-endpoints opensearch-service"

  for job in ${expected_jobs}; do
    value=""
    for i in {1..5}; do
      response=$(curl -k -s -G "${PROMETHEUS}/api/v1/query" \
        --data-urlencode "query=up{job=\"${job}\"}" 2>/dev/null)
      result_count=$(echo "${response}" | jq '.data.result | length' 2>/dev/null)
      if [[ ${result_count} -gt 0 ]]; then
        has_active=$(echo "${response}" | jq -r 'any(.data.result[]; .value[1] == "1")' 2>/dev/null)
        if [[ "${has_active}" == "true" ]]; then
          value="1"
          log "Job '${job}': up=1 (active and scraping)"
          break
        fi
      fi
      log "Attempt ${i}/5 - waiting for up=1 for job: ${job}..."
      sleep 10
    done
    assertEquals "Job '${job}' should have up=1" "1" "${value}"
  done
}

# Verify scrape jobs are collecting actual metrics.
testPrometheusMetricCollection() {
  log "Verifying actual metric collection from key scrape jobs"

  local metrics="
    kube-state-metrics:kube_node_info
    kubernetes-apiservers:apiserver_request_total
    kubernetes-nodes:kubelet_running_pods
    kubernetes-cadvisor:container_cpu_usage_seconds_total
  "

  for entry in ${metrics}; do
    job="${entry%%:*}"
    metric="${entry##*:}"
    result_count="0"
    for i in {1..5}; do
      response=$(curl -k -s -G "${PROMETHEUS}/api/v1/query" \
        --data-urlencode "query=${metric}{job=\"${job}\"}" 2>/dev/null)
      result_count=$(echo "${response}" | jq '.data.result | length' 2>/dev/null)
      result_count="${result_count:-0}"
      if [[ "${result_count}" -gt 0 ]]; then
        log "Job '${job}': ${metric} has ${result_count} series"
        break
      fi
      log "Attempt ${i}/5 - waiting for ${metric} from job ${job}..."
      sleep 10
    done
    assertNotEquals "Job '${job}' should have ${metric} data (proves actual metric collection)" \
      "0" "${result_count}"
  done
}

# Verify the Prometheus server receives remote-written data from the agent.
# kube-state-metrics is agent-only, its presence on the server proves remote-write works.
testPrometheusServerReceivesRemoteWrites() {
  log "Verifying Prometheus server receives remote-written data from agent"

  response=""
  for i in {1..5}; do
    response=$(curl -k -s -G "${PROMETHEUS}/api/v1/query" \
      --data-urlencode 'query=up{job="kube-state-metrics"}' 2>/dev/null)
    if echo "${response}" | jq -e '.data.result | length > 0' &>/dev/null; then
      result_count=$(echo "${response}" | jq '.data.result | length' 2>/dev/null)
      log "up{job=\"kube-state-metrics\"} found on server (${result_count} series) — remote-write working"
      break
    fi
    log "Attempt ${i}/5 - waiting for remote-written kube-state-metrics data..."
    sleep 10
  done

  assertContains "up{job=kube-state-metrics} should be present on server (agent-only job proves remote-write)" \
    "${response}" '"job":"kube-state-metrics"'
}

# Verify external labels are correctly set on remote-written metrics.
# The agent expands ${CLUSTER_NAME}-${TENANT_NAME}-${REGION_NICK_NAME} at runtime via env vars.
testPrometheusExternalLabelsPresent() {
  local expected_name="${CLUSTER_NAME}-${TENANT_NAME}-${REGION_NICK_NAME}"
  local expected_region="${REGION_NICK_NAME}"
  log "Expected — k8s_cluster_name: '${expected_name}' | k8s_cluster_region: '${expected_region}'"

  k8s_cluster_name=""
  k8s_cluster_region=""
  for i in {1..5}; do
    response=$(curl -k -s -G "${PROMETHEUS}/api/v1/query" \
      --data-urlencode 'query=up{job="kube-state-metrics"}' 2>/dev/null)
    result_count=$(echo "${response}" | jq '.data.result | length' 2>/dev/null)
    if [[ ${result_count} -gt 0 ]]; then
      k8s_cluster_name=$(echo "${response}" | jq -r '.data.result[0].metric.k8s_cluster_name // ""')
      k8s_cluster_region=$(echo "${response}" | jq -r '.data.result[0].metric.k8s_cluster_region // ""')
      if [[ -n "${k8s_cluster_name}" ]] && [[ -n "${k8s_cluster_region}" ]]; then
        log "Actual — k8s_cluster_name: '${k8s_cluster_name}' | k8s_cluster_region: '${k8s_cluster_region}'"
        break
      fi
    fi
    log "Attempt ${i}/5 - waiting for remote-written metrics with external labels..."
    sleep 10
  done

  assertEquals "k8s_cluster_name should match expected" "${expected_name}" "${k8s_cluster_name}"
  assertEquals "k8s_cluster_region should match expected" "${expected_region}" "${k8s_cluster_region}"
}

testPrometheusJobExporterRunning() {
  POD=$(kubectl -n prometheus get pods -l app=prometheus-job-exporter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  test -n "$POD" && kubectl -n prometheus get pod "$POD" -o jsonpath='{.status.phase}' | grep -q "Running"
  assertEquals "Prometheus job exporter pod not running" 0 $?
}

# Verify users_count_1 metrics from the job exporter are present on the server.
# Proves the agent is scraping the exporter and remote-writing the data successfully.
testPrometheusJobExporterMetricsScraped() {
  log "Verifying users_count_1 metrics from job exporter are present on server"

  response=""
  for i in {1..5}; do
    response=$(curl -k -s "${PROMETHEUS}/api/v1/query?query=users_count_1" 2>/dev/null)
    if echo "${response}" | jq -e '.data.result | length > 0' &>/dev/null; then
      count=$(echo "${response}" | jq -r '.data.result[0].value[1]' 2>/dev/null)
      log "users_count_1 present — value: ${count}"
      break
    fi
    log "Attempt ${i}/5 - waiting for users_count_1..."
    sleep 10
  done

  result_count=$(echo "${response}" | jq '.data.result | length' 2>/dev/null)
  assertNotEquals "users_count_1 should have at least one result on server" "0" "${result_count}"
}

# Verify opensearch_cluster_status metric is scraped from OpenSearch.
# Proves agent authentication and scraping of OpenSearch service endpoints is working.
testPrometheusOpenSearchMetricsScraped() {
  log "Verifying opensearch_cluster_status metric is present on server"

  response=""
  for i in {1..5}; do
    response=$(curl -k -s "${PROMETHEUS}/api/v1/query?query=opensearch_cluster_status" 2>/dev/null)
    if echo "${response}" | jq -e '.data.result | length > 0' &>/dev/null; then
      cluster=$(echo "${response}" | jq -r '.data.result[0].metric.cluster' 2>/dev/null)
      log "opensearch_cluster_status present — cluster: ${cluster}"
      break
    fi
    log "Attempt ${i}/5 - waiting for opensearch_cluster_status..."
    sleep 10
  done

  result_count=$(echo "${response}" | jq '.data.result | length' 2>/dev/null)
  assertNotEquals "opensearch_cluster_status should have at least one result on server" "0" "${result_count}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}

