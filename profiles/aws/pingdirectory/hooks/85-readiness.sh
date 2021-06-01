#!/usr/bin/env sh

. "${HOOKS_DIR}/utils.lib.sh"

# Verify that server is responsive on its LDAP secure port
beluga_log "verifying root DSE access"
curl -fks -o /dev/null https://localhost:1443/available-state || exit 1

# Verify that post-start initialization is complete on this host
beluga_log "verifying that post-start initialization is complete on ${HOSTNAME}"
test -f "${POST_START_INIT_MARKER_FILE}" && exit 0 || exit 1