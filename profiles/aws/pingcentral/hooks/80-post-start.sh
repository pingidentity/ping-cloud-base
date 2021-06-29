#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

beluga_log "post-start: starting post-start initialization"

beluga_log "post-start: Restoring JWK file to s3"
# sh "${HOOKS_DIR}/90-upload-jwk-s3.sh"
JWK_BACKUP_STATUS=0
beluga_log "post-start: engine replication status: ${JWK_BACKUP_STATUS}"

if test "${JWK_BACKUP_STATUS}" -eq 0; then
  beluga_log "post-start: exiting now"
  exit 0
fi

# Kill the container if post-start fails.
beluga_log "post-start: post-start initialization failed"
SERVER_PID=$(pgrep -f java)
kill "${SERVER_PID}"