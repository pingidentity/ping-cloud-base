#!/bin/sh
set -e

. "${HOOKS_DIR}/utils.lib.sh"

# Install AWS CLI and set required environment variables for AWS S3 bucket
initializeS3Configuration

# This is the backup directory on the server
SERVER_RESTORE_DIR="/tmp/restore"

rm -rf "${SERVER_RESTORE_DIR}"
mkdir -p "${SERVER_RESTORE_DIR}"

DATA_BACKUP_FILE=
DATA_BACKUP_FILE_NAME=$( echo "${BACKUP_FILE_NAME}" | tr -d '"' )
if ! test -z "${DATA_BACKUP_FILE_NAME}" && \
   ! test "${DATA_BACKUP_FILE_NAME}" = 'null'; then

  echo "Attempting to restore backup from S3 specified by the user: ${DATA_BACKUP_FILE_NAME}"
  DATA_BACKUP_FILE_NAME="${DIRECTORY_NAME}/${DATA_BACKUP_FILE_NAME}"
  # Get the specified backup zip file from s3
  DATA_BACKUP_FILE=$( aws s3api list-objects \
    --bucket "${BUCKET_NAME}" \
    --prefix "${DIRECTORY_NAME}/data" \
    --query "(Contents[?Key=='${DATA_BACKUP_FILE_NAME}'])[0].Key" \
    | tr -d '"' )
else
  # Filter data.zip to most recent uploaded files that occured 3 days ago.
  # AWS has a 1000 list-object limit per request. This will help filter out older backup files.
  FORMAT="+%Y-%m-%d"
  DAYS=${S3_BACKUP_FILTER_DAY_COUNT-3}
  DAYS_AGO=$(date --date="@$(($(date +%s) - (${DAYS} * 24 * 3600)))" "${FORMAT}")

  echo "S3 filter by ${S3_BACKUP_FILTER_DAY_COUNT} day(s) ago"
  echo "S3 filter by date ${DAYS_AGO}"

  # Get the name of the latest backup zip file from s3
  DATA_BACKUP_FILE=$( aws s3api list-objects \
    --bucket "${BUCKET_NAME}" \
    --prefix "${DIRECTORY_NAME}/data" \
    --query "reverse(sort_by(Contents[?LastModified>='${DAYS_AGO}'], &LastModified))[0].Key" \
    | tr -d '"' )

  echo "Attempting to restore latest uploaded backup from S3: ${DATA_BACKUP_FILE}"
fi

# If a backup file in s3 exists
if ! test -z "${DATA_BACKUP_FILE}" && \
   ! test "${DATA_BACKUP_FILE}" = 'null'; then

  # Extract only the file name
  DATA_BACKUP_FILE=${DATA_BACKUP_FILE#${DIRECTORY_NAME}/}

  # Download latest backup file from s3 bucket
  aws s3 cp ${TARGET_URL}/${DATA_BACKUP_FILE} ${SERVER_RESTORE_DIR}/${DATA_BACKUP_FILE}
  AWS_API_RESULT=${?}

  echo "Download return code: ${AWS_API_RESULT}"

  if test ${AWS_API_RESULT} -ne 0; then
    echo "Download was unsuccessful - crash the container"
    exit 1
  fi

  cd ${SERVER_RESTORE_DIR}

  # Unzip archive user data
  unzip -o "${DATA_BACKUP_FILE}"

  # Remove zip
  rm -rf "${DATA_BACKUP_FILE}"

  # Print the filename of the downloaded file from s3
  echo "Downloaded file name: ${DATA_BACKUP_FILE}"

  # Print listed files from user data archive
  ls ${SERVER_RESTORE_DIR}

  echo "Removing changelogDb before restoring user data"
  rm -rf "${SERVER_ROOT_DIR}/changelogDb"

  echo "Restoring to the latest backups under ${SERVER_RESTORE_DIR}"
  BACKEND_DIRS=$(find "${SERVER_RESTORE_DIR}" -name backup.info -exec dirname {} \;)

  # If encryption-settings backend is present in the backups, it must be restored first.
  # So re-order the backups such that it appears first in the list.
  ORDERED_BACKEND_DIRS=
  ENCRYPTION_DB_BACKEND_DIR=

  for BACKEND_DIR in ${BACKEND_DIRS}; do
    if test "${BACKEND_DIR%encryption-settings}" != "${BACKEND_DIR}"; then
      echo "Found encryption-settings database backend"
      ENCRYPTION_DB_BACKEND_DIR="${BACKEND_DIR}"
    else
      test -z "${ORDERED_BACKEND_DIRS}" &&
          ORDERED_BACKEND_DIRS="${BACKEND_DIR}" ||
          ORDERED_BACKEND_DIRS="${ORDERED_BACKEND_DIRS} ${BACKEND_DIR}"
    fi
  done

  test ! -z "${ENCRYPTION_DB_BACKEND_DIR}" &&
      ORDERED_BACKEND_DIRS="${ENCRYPTION_DB_BACKEND_DIR} ${ORDERED_BACKEND_DIRS}"

  echo "Restore order of backups: ${ORDERED_BACKEND_DIRS}"

  for BACKEND_DIR in ${ORDERED_BACKEND_DIRS}; do
    printf "\n----- Doing a restore from ${BACKEND_DIR} -----\n"
    restore --task \
      --useSSL --trustAll \
      --port ${LDAPS_PORT} \
      --bindDN "${ROOT_USER_DN}" \
      --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
      --backupDirectory "${BACKEND_DIR}" \
      --ignoreCompatibilityWarnings
  done

  # Cleanup
  rm -rf ${SERVER_RESTORE_DIR}

else

  echo "No archive user data found"
  
fi