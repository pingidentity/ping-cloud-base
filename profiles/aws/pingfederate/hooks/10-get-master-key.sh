#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

cleanUp() {
  rm -rf "${EXPORT_DIR}"
}

MASTER_KEY_FILE=pf.jwk
MASTER_KEY_PATH="${SERVER_ROOT_DIR}/server/default/data/${MASTER_KEY_FILE}"

#---------------------------------------------------------------------------------------------
# Main Script 
#---------------------------------------------------------------------------------------------

# NOTE: we wait through the WAIT_FOR_SERVICES variable in the engine's init container. So the admin
# must be running if we're here. We'll wait for the admin API specifically to ensure it's up.
beluga_log "waiting for admin API to be ready"
wait_for_admin_api_endpoint configArchive/export

beluga_log "Fetching configuration and master key from the admin server"

# Fetch the configuration and master key from the admin server
EXPORT_DIR=$(mktemp -d)
EXPORT_ZIP_FILE="${EXPORT_DIR}/data.zip"

# Force cleanUp function to run, upon exit of script or error below
trap "cleanUp" EXIT

make_api_request_download -X GET \
  "https://${PF_ADMIN_HOST_PORT}/pf-admin-api/v1/configArchive/export" \
  -o "${EXPORT_ZIP_FILE}"

RESULT=$?
(test "${RESULT}" -ne 0 ||
  test $(unzip -t ${EXPORT_ZIP_FILE} &> /dev/null; echo $?) -ne 0) &&
  beluga_log "Unable to retrieve configuration from admin" &&
  exit "${RESULT}"

beluga_log "Extracting config export to ${EXPORT_DIR}"
unzip -o "${EXPORT_ZIP_FILE}" -d "${EXPORT_DIR}"

# Copy master key to server directory and obfuscate
find "${EXPORT_DIR}" -type f -name "${MASTER_KEY_FILE}" | xargs -I {} cp {} "${MASTER_KEY_PATH}"
test ! -f "${MASTER_KEY_PATH}" && beluga_log "Unable to locate master key" && exit 1
chmod 400 "${MASTER_KEY_PATH}"
obfuscatePassword
