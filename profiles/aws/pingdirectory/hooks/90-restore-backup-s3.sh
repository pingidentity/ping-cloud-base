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
if ! test -z "${DATA_BACKUP_FILE_NAME}"; then

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

  echo "S3 filter day count ${S3_BACKUP_FILTER_DAY_COUNT}"
  echo "S3 filter by ${DAYS_AGO} day(s)"

  # Get the name of the latest backup zip file from s3
  DATA_BACKUP_FILE=$( aws s3api list-objects \
    --bucket "${BUCKET_NAME}" \
    --prefix "${DIRECTORY_NAME}/data" \
    --query "reverse(sort_by(Contents[?LastModified>='${DAYS_AGO}'], &LastModified))[0].Key" \
    | tr -d '"' )

  echo "Attempting to restore latest uploaded backup from S3: ${DATA_BACKUP_FILE}"
fi

# If a backup file in s3 exists
if ! test -z "${DATA_BACKUP_FILE}"; then

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

  echo "Restoring to the latest backup under ${SERVER_RESTORE_DIR}"
  restore --task \
    --useSSL --trustAll \
    --port ${LDAPS_PORT} \
    --bindDN "${ROOT_USER_DN}" \
    --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --backupDirectory "${SERVER_RESTORE_DIR}"

  # Cleanup
  rm -rf ${SERVER_RESTORE_DIR}

else

  echo "No archive user data found"
  
fi