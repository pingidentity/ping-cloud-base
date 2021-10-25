#!/usr/bin/env sh

. "${HOOKS_DIR}/utils.lib.sh"

heartbeat_endpoint="https://localhost:${PF_ENGINE_PORT}/pf/heartbeat.ping"

beluga_log "Starting PingFederate Engine liveness probe.  Waiting for heartbeat endpoint at ${heartbeat_endpoint}"

get_url_response_code=$(curl -k \
  -s \
  -S \
  -w '%{response_code}' \
  --max-time 2 \
  -o /dev/null \
  "${heartbeat_endpoint}")
exit_code=$?

if test ${exit_code} -eq 0 && test 200 -eq ${get_url_response_code}; then
  beluga_log "PingFederate Engine heartbeat endpoint ready"
  exit 0
else
  beluga_log "PingFederate Engine heartbeat endpoint NOT ready"
  exit 1
fi