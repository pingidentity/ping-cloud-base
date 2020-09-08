#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  readonly PD_LOG_STREAM_SUFFIX="pingdirectory-0_${NAMESPACE}_pingdirectory"
}

# Log streams are prefixed with the format of <log_name>_logs
# e.g. admin-api.log -> admin_api_logs
# e.g. access -> access_logs
# e.g. server.out -> server_logs

function test_pd_log_streams_exist() {
  local log_stream_prefixes="server access errors config_audit expensive_write_ops failed_ops replication"

  local success=0
  if ! log_streams_exist "${log_stream_prefixes}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pd_server_log_events_exist() {
  local log_stream="server_logs.${PD_LOG_STREAM_SUFFIX}"
  local full_pathname=/opt/out/instance/logs/server.out
  local pod=pingdirectory-0
  local container=pingdirectory

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pd_access_log_events_exist() {
  local log_stream="access_logs.$PD_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/logs/access
  local pod=pingdirectory-0
  local container=pingdirectory

  local success=0
  if ! log_events_exist "${log_stream}" ${full_pathname} ${pod} ${container}; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pd_errors_log_events_exist() {
  local log_stream="errors_logs.$PD_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/logs/errors
  local pod=pingdirectory-0
  local container=pingdirectory

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pd_config_audit_log_events_exist() {
  local log_stream="config_audit_logs.$PD_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/logs/config-audit.log
  local pod=pingdirectory-0
  local container=pingdirectory

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pd_expensive_write_ops_log_events_exist() {
  local log_stream="expensive_write_ops_logs.$PD_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/logs/expensive-write-ops
  local pod=pingdirectory-0
  local container=pingdirectory

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pd_failed_ops_log_events_exist() {
  local log_stream="failed_ops_logs.$PD_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/logs/failed-ops
  local pod=pingdirectory-0
  local container=pingdirectory

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pd_replication_log_events_exist() {
  local log_stream="replication_logs.$PD_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/logs/replication
  local pod=pingdirectory-0
  local container=pingdirectory

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pd_default_log_events_exist() {
  local log_stream="$PD_LOG_STREAM_SUFFIX"
  local full_pathname=unused_placeholder_variable
  local pod=pingdirectory-0
  local container=pingdirectory
  local default=true

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}" "${default}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
