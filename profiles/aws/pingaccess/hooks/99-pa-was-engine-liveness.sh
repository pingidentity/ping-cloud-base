#!/usr/bin/env sh

. "${HOOKS_DIR}/utils.lib.sh"

# PDO-1432 - The /pa/* endpoints moved to /pa-was/*
heartbeat_endpoint="https://localhost:${PA_ENGINE_PORT}/pa-was/heartbeat.ping"

beluga_log "Starting PingAccess WAS Engine liveness probe.  Waiting for heartbeat endpoint at ${heartbeat_endpoint}"

get_url_response_code=$(curl -k \
  -s \
  -S \
  -w '%{response_code}' \
  --max-time 2 \
  -o /dev/null \
  "${heartbeat_endpoint}")
exit_code=$?

if test ${exit_code} -eq 0 && test 200 -eq ${get_url_response_code}; then
  beluga_log "PingAccess WAS Engine heartbeat endpoint ready"
  exit 0
else
  beluga_log "PingAccess WAS Engine heartbeat endpoint NOT ready"
  exit 1
fi