#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

MASTER_KEY_FILE=pf.jwk
MASTER_KEY_PATH="${SERVER_ROOT_DIR}/server/default/data/${MASTER_KEY_FILE}"

#---------------------------------------------------------------------------------------------
# Main Script 
#---------------------------------------------------------------------------------------------

# NOTE: we wait through the WAIT_FOR_SERVICES variable in the engine's init container. So the admin
# must be running if we're here.

echo "Fetching master key from the admin server"

# Fetch the master key from the admin server
EXPORT_DIR=$(mktemp -d)
EXPORT_ZIP_FILE="${EXPORT_DIR}/export.zip"

make_api_request -X GET \
  "https://${PINGFEDERATE_ADMIN_SERVER}:${PF_ADMIN_PORT}/pf-admin-api/v1/configArchive/export" \
  -o "${EXPORT_ZIP_FILE}"

RESULT=$?
test "${RESULT}" -ne 0 && exit "${RESULT}"

echo "Extracting config export to ${EXPORT_DIR}"
unzip -o "${EXPORT_ZIP_FILE}" -d "${EXPORT_DIR}"

find "${EXPORT_DIR}" -type f -name "${MASTER_KEY_FILE}" | xargs -I {} cp {} "${MASTER_KEY_PATH}"
test ! -f "${MASTER_KEY_PATH}" && exit 1

chmod 400 "${MASTER_KEY_PATH}"
obfuscatePassword
