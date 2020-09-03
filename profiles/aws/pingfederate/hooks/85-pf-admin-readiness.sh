#!/usr/bin/env sh

. "${HOOKS_DIR}/utils.lib.sh"

# Verify that server is responsive on Admin API version endpoint
beluga_log "readiness: verifying the PingFederate Admin API version endpoint is accessible"
"${HOOKS_DIR}"/99-pf-admin-liveness.sh || exit 1

# Verify that post-start initialization is complete on this host
beluga_log "readiness: verifying that post-start initialization is complete on ${HOSTNAME}"
test -f "${POST_START_INIT_MARKER_FILE}" && exit 0 || exit 1