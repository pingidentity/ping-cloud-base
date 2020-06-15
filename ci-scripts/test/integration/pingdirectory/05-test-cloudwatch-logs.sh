#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

readonly PD_LOG_STREAM_SUFFIX="pingdirectory-0_${NAMESPACE}_pingdirectory"

function main() {
  local status=0
  test_pd_log_streams_exist; test $? -ne 0 && status=1
  test_pd_server_log_events_exist; test $? -ne 0 && status=1
  test_pd_access_log_events_exist; test $? -ne 0 && status=1
  test_pd_errors_log_events_exist; test $? -ne 0 && status=1
  test_pd_config_audit_log_events_exist; test $? -ne 0 && status=1
  test_pd_expensive_write_ops_log_events_exist; test $? -ne 0 && status=1
  test_pd_failed_ops_log_events_exist; test $? -ne 0 && status=1
  test_pd_replication_log_events_exist; test $? -ne 0 && status=1
  test_pd_default_log_events_exist; test $? -ne 0 && status=1
  echo "Finished $0 with status: ${status}"
  return "${status}"
}

# Log streams are prefixed with the format of <log_name>_logs
# e.g. admin-api.log -> admin_api_logs
# e.g. access -> access_logs
# e.g. server.out -> server_logs

function test_pd_log_streams_exist() {
  local log_stream_prefixes="server access errors config_audit expensive_write_ops failed_ops replication"
  echo "Running: test_pd_log_streams_exist"
  if ! log_streams_exist "${log_stream_prefixes}"; then
    echo "Fail: test_pd_log_streams_exist"
    return 1
  fi
  echo "Pass: test_pd_log_streams_exist"
  return 0
}

function test_pd_server_log_events_exist() {
  local log_stream="server_logs.${PD_LOG_STREAM_SUFFIX}"
  local full_pathname=/opt/out/instance/logs/server.out
  local pod=pingdirectory-0
  local container=pingdirectory
  echo "Running: test_pd_server_log_events_exist"
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    echo "Fail: test_pd_server_log_events_exist"
    return 1
  fi
  echo "Pass: test_pd_server_log_events_exist"
  return 0
}

function test_pd_access_log_events_exist() {
  local log_stream="access_logs.$PD_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/logs/access
  local pod=pingdirectory-0
  local container=pingdirectory
  echo "Running: test_pd_access_log_events_exist"
  if ! log_events_exist "$log_stream" $full_pathname $pod $container; then
    echo "Fail: test_pd_access_log_events_exist"
    exit 1
  fi
    echo "Pass: test_pd_access_log_events_exist"
  return 0
}

function test_pd_errors_log_events_exist() {
  local log_stream="errors_logs.$PD_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/logs/errors
  local pod=pingdirectory-0
  local container=pingdirectory
  echo "Running: test_pd_errors_log_events_exist"
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    echo "Fail: test_pd_errors_log_events_exist"
    return 1
  fi
  echo "Pass: test_pd_errors_log_events_exist"
  return 0
}

function test_pd_config_audit_log_events_exist() {
  local log_stream="config_audit_logs.$PD_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/logs/config-audit.log
  local pod=pingdirectory-0
  local container=pingdirectory
  echo "Running: test_pd_config_audit_log_events_exist"
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    echo "Fail: test_pd_config_audit_log_events_exist"
    return 1
  fi
  echo "Pass: test_pd_config_audit_log_events_exist"
  return 0
}

function test_pd_expensive_write_ops_log_events_exist() {
  local log_stream="expensive_write_ops_logs.$PD_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/logs/expensive-write-ops
  local pod=pingdirectory-0
  local container=pingdirectory
  echo "Running: test_pd_expensive_write_ops_log_events_exist"
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    echo "Fail: test_pd_expensive_write_ops_log_events_exist"
    return 1
  fi
  echo "Pass: test_pd_expensive_write_ops_log_events_exist"
  return 0
}

function test_pd_failed_ops_log_events_exist() {
  local log_stream="failed_ops_logs.$PD_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/logs/failed-ops
  local pod=pingdirectory-0
  local container=pingdirectory
  echo "Running: test_pd_failed_ops_log_events_exist"
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    echo "Fail: test_pd_failed_ops_log_events_exist"
    return 1
  fi
  echo "Pass: test_pd_failed_ops_log_events_exist"
  return 0
}

function test_pd_replication_log_events_exist() {
  local log_stream="replication_logs.$PD_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/logs/replication
  local pod=pingdirectory-0
  local container=pingdirectory
  echo "Running: test_pd_replication_log_events_exist"
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    echo "Fail: test_pd_replication_log_events_exist"
    return 1
  fi
  echo "Pass: test_pd_replication_log_events_exist"
  return 0
}

function test_pd_default_log_events_exist() {
  local log_stream="$PD_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/logs/
  local pod=pingdirectory-0
  local container=pingdirectory
  local inverse=true
  echo "Running: test_pd_default_log_events_exist"
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}" "${inverse}"; then
    echo "Fail: test_pd_default_log_events_exist"
    return 1
  fi
  echo "Pass: test_pd_default_log_events_exist"
  return 0
}

main "$@"
exit $?