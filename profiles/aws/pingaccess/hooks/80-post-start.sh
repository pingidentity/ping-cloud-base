#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

if test "${OPERATIONAL_MODE}" != "CLUSTERED_CONSOLE"; then
  beluga_log "post-start: skipping post-start on engine"
  exit 0
fi

# Remove the marker file before running post-start initialization.
rm -f "${POST_START_INIT_MARKER_FILE}"

# Wait until pingaccess admin localhost is available
pingaccess_admin_wait

# ADMIN_CONFIGURATION_COMPLETE is used as a marker file that tracks if server was initially configured.
#
# If ADMIN_CONFIGURATION_COMPLETE does not exist then set initial configuration.
if ! test -f "${ADMIN_CONFIGURATION_COMPLETE}"; then
  beluga_log "${ADMIN_CONFIGURATION_COMPLETE} not present"

  beluga_log "Starting hook: ${HOOKS_DIR}/81-import-initial-configuration.sh"
  sh "${HOOKS_DIR}/81-import-initial-configuration.sh"
  if test $? -ne 0; then
    stop_server
    exit 1
  fi

  if isPingaccessWas; then
    sh "${HOOKS_DIR}/82-configure-p14c-token-provider.sh"
    if test $? -ne 0; then
      stop_server
      exit 1
    fi

    sh "${HOOKS_DIR}/83-configure-initial-pa-was.sh"
    if test $? -ne 0; then
      stop_server
      exit 1
    fi

  fi

  touch ${ADMIN_CONFIGURATION_COMPLETE}

else

  # Since this isn't initial deployment, change password if from disk is different than the desired value.
  if test $(comparePasswordDiskWithVariable) -eq 0; then
    beluga_log "changing PA admin password"
    if ! changePassword; then
      stop_server
      exit 1
    fi
  else
    beluga_log "not changing PA admin password"
  fi

  # If P14C environment variables have changed, update the config with new values
  if isPingaccessWas; then
    beluga_log "Starting hook: ${HOOKS_DIR}/82-configure-p14c-token-provider.sh"
    sh "${HOOKS_DIR}/82-configure-p14c-token-provider.sh"
    if test $? -ne 0; then
      stop_server
      exit 1
    fi

    beluga_log "Starting hook: ${HOOKS_DIR}/83-configure-initial-pa-was.sh"
    sh "${HOOKS_DIR}/83-configure-initial-pa-was.sh"
    if test $? -ne 0; then
      stop_server
      exit 1
    fi
  fi

fi

# Update the admin config host
echo "Updating the host and port of the Admin Config..."
update_admin_config_host_port

# Upload a backup right away after starting the server.
beluga_log "Starting hook: ${HOOKS_DIR}/90-upload-backup-s3.sh"
sh "${HOOKS_DIR}/90-upload-backup-s3.sh"
BACKUP_STATUS=${?}

beluga_log "post-start: data backup status: ${BACKUP_STATUS}"

# Write the marker file if post-start succeeds.
if test "${BACKUP_STATUS}" -eq 0; then
  touch "${POST_START_INIT_MARKER_FILE}"
  exit 0
fi

# Kill the container if post-start fails.
beluga_log "post-start: admin post-start backup failed"
stop_server
exit 1
