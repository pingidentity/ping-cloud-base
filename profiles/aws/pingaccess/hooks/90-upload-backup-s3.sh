#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

initializeS3Configuration

echo "Uploading to location ${BACKUP_URL}"

DST_DIRECTORY="/tmp/k8s-s3-upload-archive"
mkdir -p ${DST_DIRECTORY}
cd ${DST_DIRECTORY}

# Make request to admin API and backup latest data
make_api_request_download -OJ -X GET https://localhost:9000/pa-admin-api/v3/backup

# Get the name of the backup file
DST_FILE=$(find ./ -iname \*.zip)
DST_FILE=${DST_FILE#./}

# Validate admin API call was successful and that zip isn't corrupted
if test $( unzip -t ${DST_FILE} > /dev/null 2>&1; echo $? ) != 0 ; then
  # Cleanup k8s-s3-upload-archive temp directory
  echo "Failed to export archive"
  rm -rf ${DST_DIRECTORY}
  exit 1
fi

echo "Creating directory ${DIRECTORY_NAME} under bucket ${BUCKET_NAME}"
aws s3api put-object --bucket "${BUCKET_NAME}" --key "${DIRECTORY_NAME}"/

aws s3 cp "${DST_DIRECTORY}/${DST_FILE}" "${TARGET_URL}/"
AWS_API_RESULT=${?}

echo "Upload return code: ${AWS_API_RESULT}"

if test ${AWS_API_RESULT} != 0; then
  echo "Upload was unsuccessful - crash the container"
  exit 1
fi

# Print the filename of the uploaded file to s3
echo "Uploaded file name: ${DST_FILE}"

# Print listed files from k8s-s3-upload-archive
DST_DIR_CONTENTS=$(mktemp)
ls ${DST_DIRECTORY} > ${DST_DIR_CONTENTS}
cat ${DST_DIR_CONTENTS}

# Cleanup k8s-s3-upload-archive temp directory
rm -rf ${DST_DIRECTORY}