#!/bin/sh

. "${HOOKS_DIR}/utils.lib.sh"

# Define variables
SCRIPT_NAME="$(basename $0)"
ERROR_MSG="Fail me"

upload_to_s3() {

  beluga_log "Copying files in '${UPLOAD_DIR}' to ${BACKUP_CLOUD_PREFIX}/pingdirectory"
  if ! awscliCopy "${UPLOAD_DIR}" "${BACKUP_CLOUD_PREFIX}/" "Recursive"; then
    ERROR_MSG="Failed to upload files in ${UPLOAD_DIR}.${ERROR_MSG}"
    beluga_error ${ERROR_MSG}
    return 1
  fi

  # Print the names of the uploaded files so callers know exactly what was uploaded
  beluga_log "The following files were uploaded:"
  ls ${UPLOAD_DIR} | xargs
}

# Perform finalization on exit
finalize() {
  # Check if there was an error running the backup script
  if [ -n "${ERROR_MSG}" ]; then

    notify "${SCRIPT_NAME} - ${ERROR_MSG} - check k8s logs for more details."
    exit 1
  fi
}
test -z "${BACKUP_RESTORE_POD}" && SERVER="${K8S_STATEFUL_SET_NAME}-0" || SERVER="${BACKUP_RESTORE_POD}"

# Trap all exit codes from here on so finalization is run
trap "finalize" EXIT

# Set required environment variables for aws cli s3 commands
initializeS3Configuration

LDAPS_PORT=1636

# This is the backup directory on the Pingdirectory-backup persistent volume
SERVER_BACKUP_DIR="/opt/backup"
UPLOAD_DIR="${SERVER_BACKUP_DIR}/backup-upload"
# Remove everything from SERVER_BACKUP_DIR sub directory /upload.
# Note, no data shouldn't exists given this is a new Persistent Volume Claim.
# However, this is here to avoid any spurious behavior such as k8s not deleting volume or failure of previous job
rm -fr "${UPLOAD_DIR}"
mkdir -p "${UPLOAD_DIR}"

BACKENDS=$(echo "${BACKENDS_TO_BACKUP}" | tr ';' ' ')

beluga_log "Doing a full backup of backends \"${BACKENDS}\" to ${UPLOAD_DIR}"

for BACKEND_ID in ${BACKENDS}; do

  /tmp/kubectl exec "${SERVER}" -c pingdirectory -- sh -c "dsconfig get-backend-prop --backend-name ${BACKEND_ID} --no-prompt"
  is_backend_found=$?

  # Run backup only if the backend exists
  if test ${is_backend_found} -eq 0; then

    BACKEND_BACKUP_DIR="${UPLOAD_DIR}/${BACKEND_ID}"

    printf "\n----- Doing a full backup of ${BACKEND_ID} backend to ${BACKEND_BACKUP_DIR} -----\n"
    /opt/out/instance/bin/backup --backupDirectory "${BACKEND_BACKUP_DIR}" --backendID "${BACKEND_ID}"
    backup_status=$?

    if test ${backup_status} -ne 0; then
      beluga_error "When generating a backup for backend_id: '${BACKEND_ID}' caused an error of status: ${backup_status}"
      ERROR_MSG="Generating a backup for backend ${BACKEND_ID} failed. ${ERROR_MSG}"
    fi
  else
    beluga_warn "BACKEND_ID='${BACKEND_ID}' was not found on the PingDirectory server"
  fi
done

# After attempting backup check if there were any errors detected
# If ERROR_MSG is set then exit script with error. We don't want to upload partial or corrupted backup to S3.
if [ -n "${ERROR_MSG}" ]; then
  exit 1
fi

# Zip backup files and append the current timestamp to zip filename
cd "${UPLOAD_DIR}" || exit 1
DST_FILE_TIMESTAMP="data-$(date +%m-%d-%Y.%H.%M.%S).zip"

# Explicitly move these files into the zip using the -m flag. The -r flag will recurse through all sub directories under UPLOAD_DIR
zip -mr "${DST_FILE_TIMESTAMP}" *

# Upload timestamp file to S3
upload_to_s3
if test $? -ne 0; then
  beluga_error "There was an issue uploading the timestamp backup '${DST_FILE_TIMESTAMP}' to S3"
  exit 1
fi

# Rename timestamp.zip to latest.zip and upload to S3 (avoided duplicating copy to avoid exceeding volume storage limit)
DST_FILE_LATEST=latest.zip

mv "${UPLOAD_DIR}/${DST_FILE_TIMESTAMP}" "${UPLOAD_DIR}/${DST_FILE_LATEST}"
upload_to_s3
if test $? -ne 0; then
  beluga_error "There was an issue uploading the backup '${DST_FILE_LATEST}' to S3"
  exit 1
fi
