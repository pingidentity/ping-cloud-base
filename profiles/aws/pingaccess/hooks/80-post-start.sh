#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

set -x

function stop_server()
{
  SERVER_PID=$(pgrep -alf java | grep 'run.properties' | awk '{ print $1; }')
  kill "${SERVER_PID}"
}

if test "${OPERATIONAL_MODE}" != "CLUSTERED_CONSOLE"; then
  echo "post-start: skipping post-start on engine"
  exit 0
fi

# Wait until pingaccess admin localhost is available
pingaccess_admin_wait

# Remove the marker file before running post-start initialization.
POST_START_INIT_MARKER_FILE="${OUT_DIR}/instance/post-start-init-complete"
rm -f "${POST_START_INIT_MARKER_FILE}"
  
# ADMIN_CONFIGURATION_COMPLETE is used as a marker file that tracks if server was initially configured.
#
# If ADMIN_CONFIGURATION_COMPLETE does not exist then set initial configuration.
ADMIN_CONFIGURATION_COMPLETE=${OUT_DIR}/instance/ADMIN_CONFIGURATION_COMPLETE
if ! test -f "${ADMIN_CONFIGURATION_COMPLETE}"; then

  sh "${HOOKS_DIR}/81-import-initial-configuration.sh"
  # Stop the server if an error has occured upon importing the intial configuration
  if test ${?} -ne 0; then
    stop_server
    exit 1
  fi

  touch ${ADMIN_CONFIGURATION_COMPLETE}
fi

# Upload a backup right away after starting the server.
sh "${HOOKS_DIR}/90-upload-backup-s3.sh"
BACKUP_STATUS=${?}

echo "post-start: data backup status: ${BACKUP_STATUS}"

# Write the marker file if post-start succeeds.
if test "${BACKUP_STATUS}" -eq 0; then
  touch "${POST_START_INIT_MARKER_FILE}"
  exit 0
fi

# Kill the container if post-start fails.
echo "post-start: admin post-start initialization failed"
stop_server