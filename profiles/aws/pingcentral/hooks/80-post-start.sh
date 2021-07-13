#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

JWK_FILE_NAME="pingcentral.jwk"
MASTER_KEY_PATH="${SERVER_ROOT_DIR}/conf/${JWK_FILE_NAME}"

beluga_log "post-start: starting post-start initialization"

if test -f "${MASTER_KEY_PATH}"; then
  beluga_log "post-start: JWK file exists exiting now"
  exit 0
fi

# Wait until pingcentral generate its JWK file for the first time
pingcental_jwk_wait "${MASTER_KEY_PATH}"

sh "${HOOKS_DIR}/90-upload-jwk-s3.sh"
JWK_UPLOAD_STATUS=$?

beluga_log "post-start: upload status: ${JWK_UPLOAD_STATUS}"

if test "${JWK_UPLOAD_STATUS}" -eq 0; then
  beluga_log "post-start: exiting now"
  exit 0
fi

# Kill the container if post-start fails.
beluga_log "post-start: post-start initialization failed"
SERVER_PID=$(pgrep -f java)
kill "${SERVER_PID}"