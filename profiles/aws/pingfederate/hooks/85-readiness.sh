#!/usr/bin/env sh

# Verify that server is responsive on its heartbeat endpoint
echo "readiness: verifying the API version endpoint is accessible"
/opt/staging/hooks/99-pf-liveness.sh || exit 1

# Verify that post-start initialization is complete on this host
echo "readiness: verifying that post-start initialization is complete on ${HOSTNAME}"
POST_START_INIT_MARKER_FILE="${OUT_DIR}/instance/post-start-init-complete"
test -f "${POST_START_INIT_MARKER_FILE}" && exit 0 || exit 1