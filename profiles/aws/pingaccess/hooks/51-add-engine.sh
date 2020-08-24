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

pingaccess_admin_wait "${ADMIN_HOST_PORT}"

# Retrieving key pair ID.
beluga_log "add-engine: retrieving the Key Pair ID"
OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/httpsListeners)
CONFIG_QUERY_LISTENER_KEYPAIR_ID=$(jq -n "${OUT}" | jq '.items[] | select(.name=="CONFIG QUERY") | .keyPairId')
beluga_log "add-engine: CONFIG_QUERY_LISTENER_KEYPAIR_ID: ${CONFIG_QUERY_LISTENER_KEYPAIR_ID}"

# Retrieving key pair alias.
beluga_log "add-engine: retrieving the Key Pair alias"
OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/keyPairs)
KEYPAIR_ALIAS_NAME=$(jq -n "${OUT}" | jq -r '.items[] | select(.id=='${CONFIG_QUERY_LISTENER_KEYPAIR_ID}') | .alias')
beluga_log "add-engine: KEYPAIR_ALIAS_NAME: ${KEYPAIR_ALIAS_NAME}"

# Retrieve Engine Cert ID.
beluga_log "add-engine: retrieving the Engine Cert ID"
OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines/certificates)
ENGINE_CERT_ID=$(jq -n "${OUT}" |
    jq --arg KEYPAIR_ALIAS_NAME "${KEYPAIR_ALIAS_NAME}" \
        '.items[] | select(.alias==$KEYPAIR_ALIAS_NAME and .keyPair==true) | .id')
beluga_log "add-engine: ENGINE_CERT_ID: ${ENGINE_CERT_ID}"

# Retrieve the Engine ID for name.
beluga_log "add-engine: retrieving the Engine ID for name ${ENGINE_NAME}"
OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines)
ENGINE_ID=$(jq -n "${OUT}" | jq --arg ENGINE_NAME "${ENGINE_NAME}" '.items[] | select(.name==$ENGINE_NAME) | .id')

# If engine doesn't exist, then create new engine.
if test -z "${ENGINE_ID}" || test "${ENGINE_ID}" = 'null'; then
  OUT=$(make_api_request -X POST -d "{
        \"name\": \"${ENGINE_NAME}\",
        \"selectedCertificateId\": ${ENGINE_CERT_ID},
        \"configReplicationEnabled\": true
    }" https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines)
  ENGINE_ID=$(jq -n "${OUT}" | jq '.id')
else
  beluga_log "add-engine: engine ${ENGINE_NAME} already exists"
fi

# Download Engine Configuration.
beluga_log "add-engine: ENGINE_ID: ${ENGINE_ID}"
beluga_log "add-engine: retrieving configuration for engine"
make_api_request_download -X POST \
    https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines/"${ENGINE_ID}"/config -o engine-config.zip

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