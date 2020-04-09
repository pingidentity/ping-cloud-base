#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

echo "Uploading to location ${LOG_ARCHIVE_URL}"

initializeS3Configuration

cd "${OUT_DIR}"

sh ${SERVER_ROOT_DIR}/bin/collect-support-data.sh
CSD_OUT=$(find . -name support\*zip -type f | sort | tail -1)

BUCKET_URL_NO_PROTOCOL=${LOG_ARCHIVE_URL#s3://}
BUCKET_NAME=$(echo "${BUCKET_URL_NO_PROTOCOL}" | cut -d/ -f1)
DIRECTORY_NAME=$(echo ${PING_PRODUCT} | tr '[:upper:]' '[:lower:]')

if test "${LOG_ARCHIVE_URL}" == */${DIRECTORY_NAME}; then
  TARGET_URL="${LOG_ARCHIVE_URL}"
else
  TARGET_URL="${LOG_ARCHIVE_URL%/}/${DIRECTORY_NAME}"
fi

echo "Creating directory ${DIRECTORY_NAME} under bucket ${BUCKET_NAME}"
aws s3api put-object --bucket "${BUCKET_NAME}" --key "${DIRECTORY_NAME}"/

FORMAT="+%d/%b/%Y:%H:%M:%S %z"
NOW=$(date "${FORMAT}")

echo "Uploading "${CSD_OUT}" to ${TARGET_URL} at ${NOW}"
DST_FILE=$(basename "${CSD_OUT}")
aws s3 cp "${CSD_OUT}" "${TARGET_URL}/${DST_FILE}"

AWS_API_RESULT="${?}"

echo "Upload return code: ${AWS_API_RESULT}"

if [ "${AWS_API_RESULT}" != "0" ]; then
  echo "Upload was unsuccessful - crash the container"
  exit 1
fi

# Remove the CSD file so it is doesn't fill up the server's filesystem.
rm -f "${CSD_OUT}"

# Print the filename so callers can figure out the name of the CSD file that was uploaded.
echo "${DST_FILE}"