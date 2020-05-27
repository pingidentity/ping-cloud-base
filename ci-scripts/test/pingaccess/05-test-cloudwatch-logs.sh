#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. "${SCRIPT_HOME}"/../../common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

readonly PA_ADMIN_LOG_STREAM_SUFFIX="pingaccess-admin-0_${NAMESPACE}_pingaccess-admin"
readonly PA_ENGINE_LOG_STREAM_SUFFIX="pingaccess-0_${NAMESPACE}_pingaccess"

function main() {
  local status=0
  test_pa_log_streams_exist; test $? -ne 0 && status=1
  test_pa_pingaccess_log_events_exist; test $? -ne 0 && status=1
  test_pa_agent_audit_log_events_exist; test $? -ne 0 && status=1
  test_pa_api_audit_log_events_exist; test $? -ne 0 && status=1
  test_pa_default_log_events_exist; test $? -ne 0 && status=1
  echo "Finished $0 with status: ${status}"
  return "${status}"
}

# Log streams are prefixed with the format of <log_name>_logs
# e.g. admin-api.log -> admin_api_logs
# e.g. access -> access_logs
# e.g. server.out -> server_logs

function test_pa_log_streams_exist() {
  local log_stream_prefixes="pingaccess_api_audit pingaccess_agent_audit pingaccess_logs"
  echo "Running: test_pa_log_streams_exist"
  if ! log_streams_exist "${log_stream_prefixes}"; then
    echo "Fail: test_pa_log_streams_exist"
    return 1
  fi
  echo "Pass: test_pa_log_streams_exist"
  return 0
}

function test_pa_pingaccess_log_events_exist() {
  local log_stream="pingaccess_logs.$PA_ADMIN_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/log/pingaccess.log
  local pod=pingaccess-admin-0
  local container=pingaccess-admin
  echo "Running: test_pa_pingaccess_log_events_exist"
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    echo "Fail: test_pa_pingaccess_log_events_exist"
    return 1
  fi
  echo "Pass: test_pa_pingaccess_log_events_exist"
  return 0
}

function test_pa_agent_audit_log_events_exist() {
  local log_stream="pingaccess_agent_audit_logs.$PA_ENGINE_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/log/pingaccess_agent_audit.log
  local pod=pingaccess-0
  local container=pingaccess
  echo "Running: test_pa_agent_audit_log_events_exist"
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    echo "Fail: test_pa_agent_audit_log_events_exist"
    return 1
  fi
  echo "Pass: test_pa_agent_audit_log_events_exist"
  return 0
}

function test_pa_api_audit_log_events_exist() {
  local log_stream="pingaccess_api_audit_logs.$PA_ADMIN_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/log/pingaccess_api_audit.log
  local pod=pingaccess-admin-0
  local container=pingaccess-admin
  echo "Running: test_pa_api_audit_log_events_exist"
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    echo "Fail: test_pa_api_audit_log_events_exist"
    return 1
  fi
  echo "Pass: test_pa_api_audit_log_events_exist"
  return 0
}

function test_pa_default_log_events_exist() {
  local log_stream="$PA_ADMIN_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/log
  local pod=pingaccess-admin-0
  local container=pingaccess-admin
  local inverse=true
  echo "Running: test_pa_default_log_events_exist"
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}" "${inverse}"; then
    echo "Fail: test_pa_default_log_events_exist"
    return 1
  fi
  echo "Pass: test_pa_default_log_events_exist"
  return 0
}

main "$@"
exit $?