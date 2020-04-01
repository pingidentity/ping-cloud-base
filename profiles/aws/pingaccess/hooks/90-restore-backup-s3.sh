#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

set -x

# 1) Specified backup file name by user will be restored 
#
# OR
#
# 2) If the master key doesn't exist within the image. There may have been 
#    an issue with the EBS volume which the 90-restore-backup-s3.sh restore script
#    will restore the latest configuration from S3. If this is an initial
#    deployment the restore scipt will not find any backups within S3.
if ! test -z "${BACKUP_FILE_NAME}" || ! test -f "${OUT_DIR}"/instance/conf/pa.jwk; then

  initializeS3Configuration

  echo "Restoring from location ${BACKUP_URL}"

  # This is the backup directory on the server
  SERVER_RESTORE_DIR="/tmp/restore"
  rm -rf "${SERVER_RESTORE_DIR}"
  mkdir -p "${SERVER_RESTORE_DIR}"

  DATA_BACKUP_FILE=
  DATA_BACKUP_FILE_NAME=$( echo "${BACKUP_FILE_NAME}" | tr -d '"' | tr -d '[:space:]' )
  if ! test -z "${DATA_BACKUP_FILE_NAME}" && \
     ! test "${DATA_BACKUP_FILE_NAME}" = 'null'; then

    echo "Attempting to restore backup from S3 specified by the user: ${DATA_BACKUP_FILE_NAME}"
    DATA_BACKUP_FILE_NAME="${DIRECTORY_NAME}/${DATA_BACKUP_FILE_NAME}"

    # Get the specified backup zip file from s3
    DATA_BACKUP_FILE=$( aws s3api list-objects \
      --bucket "${BUCKET_NAME}" \
      --prefix "${DIRECTORY_NAME}/pa-data" \
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
      --prefix "${DIRECTORY_NAME}/pa-data" \
      --query "reverse(sort_by(Contents[?LastModified>='${DAYS_AGO}'], &LastModified))[0].Key" \
      | tr -d '"' )

    echo "Attempting to restore latest uploaded backup from S3: ${DATA_BACKUP_FILE}"
  fi

  # If a backup file in s3 exist
  if ! test -z "${DATA_BACKUP_FILE}" && \
     ! test "${DATA_BACKUP_FILE}" = 'null'; then

    # extract only the file name
    DATA_BACKUP_FILE=${DATA_BACKUP_FILE#${DIRECTORY_NAME}/}

    # Rename s3 backup filename when copying onto pingfederate admin
    DST_FILE="data.zip"

    # Download latest backup file from s3 bucket
    aws s3 cp "${TARGET_URL}/${DATA_BACKUP_FILE}" "${SERVER_RESTORE_DIR}/${DST_FILE}"
    AWS_API_RESULT=${?}

    echo "Download return code: ${AWS_API_RESULT}"

    if test ${AWS_API_RESULT} != 0; then
      echo "Download was unsuccessful - crash the container"
      exit 1
    fi

    echo "importing configuration"

    # Unzip backup configuration
    unzip -o "${SERVER_RESTORE_DIR}/${DST_FILE}" -d ${OUT_DIR}/instance

    # Remove zip
    rm -rf "${SERVER_RESTORE_DIR}/${DST_FILE}"

    # Print the filename of the downloaded file from s3
    echo "Downloaded file name: ${DATA_BACKUP_FILE}"

  else

    echo "No archive data found"
    
  fi
fi
