#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

if test "${OPERATIONAL_MODE}" != "CLUSTERED_CONSOLE"; then
  echo "post-start: skipping post-start on engine"
  exit 0
fi

echo "post-start: starting admin post-start initialization"

# Remove the marker file before running post-start initialization.
POST_START_INIT_MARKER_FILE="${OUT_DIR}/instance/post-start-init-complete"
rm -f "${POST_START_INIT_MARKER_FILE}"

# Wait until the admin API is up and running.
echo "post-start: waiting for admin API to be ready"
wait_for_admin_api_endpoint configArchive/export

# Upload a backup right away after starting the server.
echo "post-start: uploading data backup to s3"
sh "${HOOKS_DIR}/82-upload-archive-data-s3.sh"

BACKUP_STATUS=${?}
echo "post-start: data backup status: ${BACKUP_STATUS}"

# Write the marker file if post-start succeeds.
if test "${BACKUP_STATUS}" -eq 0; then
  touch "${POST_START_INIT_MARKER_FILE}"
  exit 0
fi

# Kill the container if post-start fails.
echo "post-start: admin post-start initialization failed"
SERVER_PID=$(pgrep -alf java | grep 'run.properties' | awk '{ print $1; }')
kill "${SERVER_PID}"