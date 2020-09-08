#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  readonly PF_LOG_STREAM_SUFFIX="pingfederate-admin-0_${NAMESPACE}_pingfederate-admin"
  readonly PF_ENGINE_POD=$(kubectl get pod -o name -n "${NAMESPACE}" -l role=pingfederate-engine | head -1 | cut -d/ -f2)
  readonly PF_ENGINE_LOG_STREAM_SUFFIX="${PF_ENGINE_POD}_${NAMESPACE}_pingfederate"
}

# Log streams are prefixed with the format of <log_name>_logs
# e.g. admin-api.log -> admin_api_logs
# e.g. access -> access_logs
# e.g. server.out -> server_logs

function test_pf_log_streams_exist() {
  local log_stream_prefixes="jvm_garbage_collection server init admin_logs admin_api provisioner_logs"

  local success=0
  if ! log_streams_exist "${log_stream_prefixes}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pf_jvm_garbage_collection_log_events_exist() {
  local log_stream="jvm_garbage_collection_logs.$PF_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/log/jvm-garbage-collection.log
  local pod=pingfederate-admin-0
  local container=pingfederate-admin

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pf_server_log_events_exist() {
  local log_stream="server_logs.$PF_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/log/server.log
  local pod=pingfederate-admin-0
  local container=pingfederate-admin

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pf_init_log_events_exist() {
  local log_stream="init_logs.$PF_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/log/init.log
  local pod=pingfederate-admin-0
  local container=pingfederate-admin

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pf_admin_log_events_exist() {
  local log_stream="admin_logs.$PF_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/log/admin.log
  local pod=pingfederate-admin-0
  local container=pingfederate-admin

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pf_admin_api_log_events_exist() {
  local log_stream="admin_api_logs.$PF_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/log/admin-api.log
  local pod=pingfederate-admin-0
  local container=pingfederate-admin

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pf_provisioner_log_events_exist() {
  local log_stream="provisioner_logs.$PF_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/log/provisioner.log
  local pod=pingfederate-admin-0
  local container=pingfederate-admin

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

function test_pf_default_log_events_exist() {
  local log_stream="$PF_LOG_STREAM_SUFFIX"
  local full_pathname=unused_placeholder_variable
  local pod=pingfederate-admin-0
  local container=pingfederate-admin
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
