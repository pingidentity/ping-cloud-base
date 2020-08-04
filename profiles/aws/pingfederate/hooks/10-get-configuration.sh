#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

MASTER_KEY_FILE=pf.jwk
MASTER_KEY_PATH="${SERVER_ROOT_DIR}/server/default/data/${MASTER_KEY_FILE}"
DEPLOYER_PATH="${SERVER_ROOT_DIR}/server/default/data/drop-in-deployer"

#---------------------------------------------------------------------------------------------
# Main Script 
#---------------------------------------------------------------------------------------------

# NOTE: we wait through the WAIT_FOR_SERVICES variable in the engine's init container. So the admin
# must be running if we're here.

beluga_log "Fetching configuration and master key from the admin server"

# Fetch the configuration and master key from the admin server
EXPORT_DIR=$(mktemp -d)
EXPORT_ZIP_FILE="${EXPORT_DIR}/data.zip"

echo "get-master-key: PingFederate config settings"
export_config_settings

make_api_request_download -X GET \
  "https://${PINGFEDERATE_ADMIN_SERVER}:${PF_ADMIN_PORT}/pf-admin-api/v1/configArchive/export" \
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

# Deploy engine configuration using drop-in-deployer
cp "${EXPORT_ZIP_FILE}" "${DEPLOYER_PATH}"