#!/usr/bin/env sh

set_script_variables() {
  # This is the backup directory on the server
  SERVER_RESTORE_DIR="${OUT_DIR}/restore"
  rm -rf "${SERVER_RESTORE_DIR}"
  mkdir -p "${SERVER_RESTORE_DIR}"

  MASTER_KEY_FILE=pf.jwk
  MASTER_KEY_PATH="${SERVER_ROOT_DIR}/server/default/data/${MASTER_KEY_FILE}"
  DEPLOYER_PATH="${SERVER_ROOT_DIR}/server/default/data/drop-in-deployer"

  DATA_BACKUP_FILE_NAME=$( echo "${BACKUP_FILE_NAME}" | tr -d '"' | tr -d '[:space:]' )
  if ! test -z "${DATA_BACKUP_FILE_NAME}" && \
    ! test "${DATA_BACKUP_FILE_NAME}" = 'null'; then

    beluga_log "Attempting to restore backup from cloud storage specified by the user: ${DATA_BACKUP_FILE_NAME}"
  else
    beluga_log "Attempting to restore backup from latest backup file in cloud storage."
    DATA_BACKUP_FILE_NAME="latest.zip"
  fi

  # Rename backup filename when copying onto pingfederate admin
  DST_FILE="data.zip"
}
