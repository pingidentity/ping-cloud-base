#!/usr/bin/env sh

. "${HOOKS_DIR}/utils.lib.sh"

version_endpoint="https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/version"
beluga_log "Starting PingFederate Admin liveness probe.  Waiting for Admin API endpoint at ${version_endpoint}"

get_version_response_code=$(curl -k \
  -s \
  -S \
  -w '%{response_code}' \
  --max-time 2 \
  -u "${PF_ADMIN_USER_USERNAME}:${PF_ADMIN_USER_PASSWORD}" \
  -H 'X-Xsrf-Header: PingFederate' \
  -o /dev/null \
  "${version_endpoint}")

exit_code=$?
if test ${exit_code} -eq 0 && test 200 -eq ${get_version_response_code}; then
  beluga_log "PingFederate Admin API endpoint version ready"
  exit 0
else
  beluga_log "PingFederate Admin API endpoint version NOT ready"
  exit 1
fi


