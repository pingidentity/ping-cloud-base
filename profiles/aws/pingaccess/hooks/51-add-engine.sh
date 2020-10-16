#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

if test ! "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"; then
  beluga_log "add-engine: this server is not an engine"
  exit
fi

beluga_log "add-engine: starting add engine script"

SHORT_HOST_NAME=$(hostname)
ORDINAL=${SHORT_HOST_NAME##*-}
PINGACCESS_ADMIN_API_ENDPOINT="https://${ADMIN_HOST_PORT}/pa-admin-api/v3"
TEMPLATES_DIR_PATH=${STAGING_DIR}/templates/51

pingaccess_admin_wait "${ADMIN_HOST_PORT}"

# Retrieving key pair ID.
beluga_log "add-engine: retrieving the Key Pair ID"
HTTPS_LISTENERS=$(make_api_request "${PINGACCESS_ADMIN_API_ENDPOINT}/httpsListeners")
test $? -ne 0 && exit 1

CONFIG_QUERY_LISTENER_KEYPAIR_ID=$(jq -n "${HTTPS_LISTENERS}" | jq '.items[] | select(.name=="CONFIG QUERY") | .keyPairId')
beluga_log "add-engine: CONFIG_QUERY_LISTENER_KEYPAIR_ID: ${CONFIG_QUERY_LISTENER_KEYPAIR_ID}"

# Retrieving key pair alias.
beluga_log "add-engine: retrieving the Key Pair alias"
KEY_PAIRS=$(make_api_request "${PINGACCESS_ADMIN_API_ENDPOINT}/keyPairs")
test $? -ne 0 && exit 1

KEYPAIR_ALIAS_NAME=$(jq -n "${KEY_PAIRS}" | jq -r '.items[] | select(.id=='${CONFIG_QUERY_LISTENER_KEYPAIR_ID}') | .alias')
beluga_log "add-engine: KEYPAIR_ALIAS_NAME: ${KEYPAIR_ALIAS_NAME}"

# Retrieve Engine Cert ID.
beluga_log "add-engine: retrieving the Engine Cert ID"
ENGINE_CERTIFICATES=$(make_api_request "${PINGACCESS_ADMIN_API_ENDPOINT}/engines/certificates")
test $? -ne 0 && exit 1

# Export ENGINE_CERT_ID so it will get injected into
# new-engine.json.
export ENGINE_CERT_ID=$(jq -n "${ENGINE_CERTIFICATES}" |
    jq --arg KEYPAIR_ALIAS_NAME "${KEYPAIR_ALIAS_NAME}" \
        '.items[] | select(.alias==$KEYPAIR_ALIAS_NAME and .keyPair==true) | .id')
beluga_log "add-engine: ENGINE_CERT_ID: ${ENGINE_CERT_ID}"

# Retrieve the Engine ID for name.
beluga_log "add-engine: retrieving the Engine ID for name ${ENGINE_NAME}"
ENGINES=$(make_api_request "${PINGACCESS_ADMIN_API_ENDPOINT}/engines")
test $? -ne 0 && exit 1

ENGINE_ID=$(jq -n "${ENGINES}" | jq --arg ENGINE_NAME "${ENGINE_NAME}" '.items[] | select(.name==$ENGINE_NAME) | .id')

# If engine doesn't exist, then create new engine.
if test -z "${ENGINE_ID}" || test "${ENGINE_ID}" = 'null'; then

  beluga_log "add-engine: engine ${ENGINE_NAME} doesn't exist. Creating engine now."

  new_engine_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/new-engine.json)

  NEW_ENGINE=$(make_api_request -X POST -d "${new_engine_payload}" "${PINGACCESS_ADMIN_API_ENDPOINT}/engines")
  test $? -ne 0 && exit 1

  ENGINE_ID=$(jq -n "${NEW_ENGINE}" | jq '.id')
else
  beluga_log "add-engine: engine ${ENGINE_NAME} already exists"
fi

# Download Engine Configuration.
beluga_log "add-engine: ENGINE_ID: ${ENGINE_ID}"
beluga_log "add-engine: retrieving configuration for engine"
make_api_request_download -X POST \
    "${PINGACCESS_ADMIN_API_ENDPOINT}/engines/${ENGINE_ID}/config" -o engine-config.zip
test $? -ne 0 && exit 1

# Validate zip.
beluga_log "add-engine: validating downloaded config archive"
if test $(unzip -t engine-config.zip &> /dev/null; echo $?) -ne 0; then
  beluga_log "add-engine: failure retrieving config admin zip for engine"
  exit 1
fi

beluga_log "add-engine: extracting config files to conf folder"
unzip -o engine-config.zip -d "${OUT_DIR}"/instance
chmod 400 "${OUT_DIR}"/instance/conf/pa.jwk

if is_secondary_cluster; then
  if ! sed -i "s/engine.admin.configuration.port.*/engine.admin.configuration.port=${CLUSTER_CONFIG_PORT}/g" /opt/out/instance/conf/bootstrap.properties; then
    beluga_log "add-engine: failed to update admin port"
    exit 1
  fi
  if ! sed -i "s/engine.admin.configuration.host.*/engine.admin.configuration.host=${CLUSTER_PUBLIC_HOSTNAME}/g" /opt/out/instance/conf/bootstrap.properties; then
    beluga_log "add-engine: failed to update admin host"
    exit 1
  fi
fi

beluga_log "add-engine: cleaning up zip"
rm engine-config.zip

beluga_log "add-engine: finished add engine script"