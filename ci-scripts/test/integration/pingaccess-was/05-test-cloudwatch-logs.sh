#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  readonly PA_WAS_ADMIN_LOG_STREAM_SUFFIX="pingaccess-was-admin-0_${NAMESPACE}_pingaccess-was-admin"
}

testPaWasLogStreamsExist() {
  local log_stream_prefixes="pingaccess_api_audit pingaccess_logs"

  local success=0
  if ! log_streams_exist "${log_stream_prefixes}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

testPaWasPingaccessLogEventsExist() {
  local log_stream="pingaccess_logs.$PA_WAS_ADMIN_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/log/pingaccess.log
  local pod=pingaccess-was-admin-0
  local container=pingaccess-was-admin

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

testPaWasApiAuditLogEventsExist() {
  local log_stream="pingaccess_api_audit_logs.$PA_WAS_ADMIN_LOG_STREAM_SUFFIX"
  local full_pathname=/opt/out/instance/log/pingaccess_api_audit.log
  local pod=pingaccess-was-admin-0
  local container=pingaccess-was-admin

  local success=0
  if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}"; then
    success=1
  fi

  assertEquals 0 ${success}
}

# testPaWasDefaultLogEventsExist() {
#   local log_stream="$PA_WAS_ADMIN_LOG_STREAM_SUFFIX"
#   local full_pathname=unused_placeholder_variable
#   local pod=pingaccess-was-admin-0
#   local container=pingaccess-was-admin
#   local default=true
#
#   local success=0
#   if ! log_events_exist "${log_stream}" "${full_pathname}" "${pod}" "${container}" "${default}"; then
#     success=1
#   fi
#
#   assertEquals 0 ${success}
# }

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
