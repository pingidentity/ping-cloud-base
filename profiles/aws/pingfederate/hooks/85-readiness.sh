#!/usr/bin/env sh

. "${HOOKS_DIR}/utils.lib.sh"

echo "export config settings"
export_config_settings

# Verify that server is responsive on its heartbeat endpoint
beluga_log "readiness: verifying the API version endpoint is accessible"
/opt/staging/hooks/99-pf-liveness.sh || exit 1

# Verify that post-start initialization is complete on this host
beluga_log "readiness: verifying that post-start initialization is complete on ${HOSTNAME}"
test -f "${POST_START_INIT_MARKER_FILE}" && exit 0 || exit 1