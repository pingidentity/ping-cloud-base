#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

if test ! "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"; then
  echo "add-engine: this server is not an engine"
  exit
fi

echo "add-engine: starting add engine script"

echo "add-engine: pingaccess config settings"
export_config_settings

SHORT_HOST_NAME=$(hostname)
ORDINAL=${SHORT_HOST_NAME##*-}

# if is_secondary_cluster; then

#   # Secondary-cluster PA engines should use cert and alias name of the cert added to PA admin with value of K8S_ACME_CERT_SECRET_NAME.
#   if test -z "${K8S_ACME_CERT_SECRET_NAME}"; then
#       echo "add-engine: K8S_ACME_CERT_SECRET_NAME is not set"
#       exit 1
#   fi

#   # Retrieve Engine Cert ID.
#   echo "add-engine: retrieving the Engine Cert ID"
#   OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines/certificates)
#   ENGINE_CERT_ID=$(jq -n "${OUT}" | jq --arg b "${K8S_ACME_CERT_SECRET_NAME}" -r '.items[] | select(.alias==$b and .trustedCertificate==true) | .id')
#   echo "add-engine: ENGINE_CERT_ID: ${ENGINE_CERT_ID}"

# else

pingaccess_admin_wait "${ADMIN_HOST_PORT}"

# Retrieving key pair ID.
echo "add-engine: retrieving the Key Pair ID"
OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/httpsListeners)
CONFIG_QUERY_LISTENER_KEYPAIR_ID=$(jq -n "${OUT}" | jq '.items[] | select(.name=="CONFIG QUERY") | .keyPairId')
echo "add-engine: CONFIG_QUERY_LISTENER_KEYPAIR_ID: ${CONFIG_QUERY_LISTENER_KEYPAIR_ID}"

# Retrieving key pair alias.
echo "add-engine: retrieving the Key Pair alias"
OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/keyPairs)
KEYPAIR_ALIAS_NAME=$(jq -n "${OUT}" | jq -r '.items[] | select(.id=='${CONFIG_QUERY_LISTENER_KEYPAIR_ID}') | .alias')
echo "add-engine: KEYPAIR_ALIAS_NAME: ${KEYPAIR_ALIAS_NAME}"

# Retrieve Engine Cert ID.
echo "add-engine: retrieving the Engine Cert ID"
OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines/certificates)
ENGINE_CERT_ID=$(jq -n "${OUT}" |
    jq --arg KEYPAIR_ALIAS_NAME "${KEYPAIR_ALIAS_NAME}" \
        '.items[] | select(.alias==$KEYPAIR_ALIAS_NAME and .keyPair==true) | .id')
echo "add-engine: ENGINE_CERT_ID: ${ENGINE_CERT_ID}"

# fi

# Retrieve the Engine ID for name.
echo "add-engine: retrieving the Engine ID for name ${ENGINE_NAME}"
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
  echo "add-engine: engine ${ENGINE_NAME} already exists"
fi

# Download Engine Configuration.
echo "add-engine: ENGINE_ID: ${ENGINE_ID}"
echo "add-engine: retrieving configuration for engine"
make_api_request_download -X POST \
    https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines/"${ENGINE_ID}"/config -o engine-config.zip

# Validate zip.
echo "add-engine: validating downloaded config archive"
if test $(unzip -t engine-config.zip &> /dev/null; echo $?) -ne 0; then
  echo "add-engine: failure retrieving config admin zip for engine"
  exit 1
fi

echo "add-engine: extracting config files to conf folder"
unzip -o engine-config.zip -d "${OUT_DIR}"/instance
chmod 400 "${OUT_DIR}"/instance/conf/pa.jwk

if is_secondary_cluster; then
  if ! sed -i "s/engine.admin.configuration.port.*/engine.admin.configuration.port=${CLUSTER_CONFIG_PORT}/g" /opt/out/instance/conf/bootstrap.properties; then
    echo "add-engine: failed to update admin port"
    exit 1
  fi
  if ! sed -i "s/engine.admin.configuration.host.*/engine.admin.configuration.host=10.104.228.64/g" /opt/out/instance/conf/bootstrap.properties; then
    echo "add-engine: failed to update admin host"
    exit 1
  fi
fi



echo "add-engine: cleaning up zip"
rm engine-config.zip

echo "add-engine: finished add engine script"