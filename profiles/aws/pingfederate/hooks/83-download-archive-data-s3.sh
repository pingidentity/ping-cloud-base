#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

# Allow overriding the backup URL with an arg
test ! -z "${1}" && BACKUP_URL="${1}"
echo "Downloading from location ${BACKUP_URL}"

# Install AWS CLI if the upload location is S3
if test "${BACKUP_URL#s3}" == "${BACKUP_URL}"; then
   echo "Upload location is not S3"
   exit 1
else
   installTools
fi

BUCKET_URL_NO_PROTOCOL=${BACKUP_URL#s3://}
BUCKET_NAME=$(echo ${BUCKET_URL_NO_PROTOCOL} | cut -d/ -f1)

DIRECTORY_NAME=$(echo ${PING_PRODUCT} | tr '[:upper:]' '[:lower:]')

if test "${BACKUP_URL}" == */"${DIRECTORY_NAME}"; then
  TARGET_URL="${BACKUP_URL}"
else
  TARGET_URL="${BACKUP_URL}/${DIRECTORY_NAME}"
fi

# Filter data.zip to most recent uploaded files that occured 1 day ago.
# AWS has a 1000 list-object limit per request. This will help filter out older backup files.
FORMAT="+%Y-%m-%d"
DAYS=${S3_BACKUP_FILTER_DAY_COUNT:-1}
DAYS_AGO=$(date --date="@$(($(date +%s) - (${DAYS} * 24 * 3600)))" "${FORMAT}")

echo "S3 filter by ${DAYS} day(s) ago"
echo "S3 filter by date ${DAYS_AGO}"

# Check and verify that there is a backup file within S3 bucket
BUCKET_FILES=
API_RETRY_ATTEMPTS=${API_RETRY_LIMIT:-10}
while test ${API_RETRY_ATTEMPTS} -gt 0; do
  BUCKET_FILES=$( aws s3api list-objects \
  --bucket "${BUCKET_NAME}" \
  --prefix "${DIRECTORY_NAME}/data" \
  --query '(Contents[?LastModified>=`${DAYS_AGO}`].{Key: Key, LastModified: LastModified})' \
  --output json )
  AWS_ERROR_STATUS=${?}

  if test ${AWS_ERROR_STATUS} -ne 0; then
    API_RETRY_ATTEMPTS=$((${API_RETRY_ATTEMPTS}-1))
    echo "Error occured with aws s3api CLI - will retry ${API_RETRY_ATTEMPTS}"
    sleep 2s
  else
    break
  fi
done

if test ${API_RETRY_ATTEMPTS} -eq 0; then
  echo "Exceeded attempts of connecting to s3 bucket: ${BUCKET_NAME}"
  echo "Error code: ${AWS_ERROR_STATUS}"
  exit 1
fi

# If at least 1 backup file was found in the bucket, sort by LastModified and get the latest file that was uploaded to s3
if ! test -z "${BUCKET_FILES}" && ! test "${BUCKET_FILES}" = 'null'; then
  DATA_BACKUP_FILE=$( echo "${BUCKET_FILES}" | jq .[] | jq -s -c -r 'sort_by(.LastModified) | reverse | .[0] | .Key')
else
  echo "No archive data found"
  exit 0
fi

# extract only the file name
DATA_BACKUP_FILE=${DATA_BACKUP_FILE#${DIRECTORY_NAME}/}

# Rename s3 backup filename when copying onto pingfederate admin
DST_FILE="data.zip"

# Download latest backup file from s3 bucket
aws s3 cp "${TARGET_URL}/${DATA_BACKUP_FILE}" "${OUT_DIR}/instance/server/default/data/drop-in-deployer/${DST_FILE}"
AWS_API_RESULT="${?}"

echo "Download return code: ${AWS_API_RESULT}"

if [ "${AWS_API_RESULT}" != "0" ]; then
  echo "Download was unsuccessful - crash the container"
  exit 1
fi

unzip -o "${OUT_DIR}/instance/server/default/data/drop-in-deployer/${DST_FILE}" \
    pf.jwk \
    -d "${OUT_DIR}/instance/server/default/data"

# Print the filename of the downloaded file from s3
echo "Download file name: ${DATA_BACKUP_FILE}"

# Print listed files from drop-in-deployer
ls ${OUT_DIR}/instance/server/default/data/drop-in-deployer