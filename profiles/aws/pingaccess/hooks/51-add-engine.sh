#!/usr/bin/env sh

. "${HOOKS_DIR}/utils.lib.sh" > /dev/null
. "${HOOKS_DIR}"/util/add-engine-utils.sh > /dev/null

"${VERBOSE}" && set -x

if test ! "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"; then
  beluga_log "This server is not an engine"
  exit 0
fi

beluga_log "Starting add engine script..."

SHORT_HOST_NAME=$(hostname)
ORDINAL=${SHORT_HOST_NAME##*-}
PINGACCESS_ADMIN_API_ENDPOINT="https://${ADMIN_HOST_PORT}/pa-admin-api/v3"
TEMPLATES_DIR_PATH=${STAGING_DIR}/templates/51

pingaccess_admin_wait "${ADMIN_HOST_PORT}"

# Establish which PA version this image is running.
IMAGE_VERSION=
get_image_version
beluga_log "Engine Image version is: ${IMAGE_VERSION}"

# Establish running version of the admin server.
INSTALLED_ADMIN=$(get_admin_version)

# Are the admin and Engine running the same version?
if test $(format_version "${IMAGE_VERSION}") -ne $(format_version "${INSTALLED_ADMIN}"); then
  beluga_error "FATAL ERROR ILLEGAL STATE VERSION MISMATCH: Engine version ${IMAGE_VERSION} Admin Version ${INSTALLED_ADMIN}"
  exit 1
fi

beluga_log "Retrieving the HttpsListeners..."
https_listeners=$(get_https_listeners)
if test $? -ne 0; then
  beluga_error "Retrieving all of the HttpsListeners was unsuccessful."
  beluga_error "The HttpListeners response was: ${https_listeners}"
  exit 1
else
  beluga_log "Successfully retrieved all of the HttpsListeners"
fi

# Find the KeyPair attached to the CONFIG QUERY listener
beluga_log "Processing the HttpsListeners to get the Config Query key pair id..."
key_pair_id=$(get_key_pair_id "${https_listeners}")
if test $? -ne 0; then
  beluga_error "Processing the HttpsListeners json was unsuccessful."
  beluga_error "The HttpsListeners response was: ${https_listeners}"
  beluga_error "The result from parsing to get the key pair id was: ${key_pair_id}"
  exit 1
else
  beluga_log "Successfully located the Config Query Listener Key Pair ID: ${key_pair_id}"
fi

beluga_log "Retrieving all of the KeyPairs..."
key_pairs=$(get_key_pairs)
if test $? -ne 0; then
  beluga_error "Retrieving all of the KeyPairs was unsuccessful."
  beluga_error "The response was: ${key_pairs}"
  exit 1
else
  beluga_log "Successfully retrieved all of the KeyPairs"
fi

# Retrieving key pair alias.
beluga_log "Processing the KeyPairs to get the alias matching the correct key pair id..."
keypair_alias=$(get_alias "${key_pairs}" "${key_pair_id}")
if test $? -ne 0; then
  beluga_error "Processing the KeyPairs to get the correct alias was unsuccessful."
  beluga_error "The response was: ${keypair_alias}"
  exit 1
else
  beluga_log "Successfully located the KeyPair alias affiliated with the Config Query HttpsListener: ${keypair_alias}"
fi

beluga_log "Retrieving all of the TrustedCertificates available for engines..."
engine_certs=$(get_engine_trusted_certs)
if test $? -ne 0; then
  beluga_error "Retrieving the TrustedCertificates was unsuccessful."
  beluga_error "The response was: ${engine_certs}"
  exit 1
else
  beluga_log "Successfully retrieved all of the TrustedCertificates for engines"
fi

# Export ENGINE_CERT_ID so it will get injected into
# new-engine.json.
# export ENGINE_CERT_ID
beluga_log "Processing the TrustedCertificates to get the correct certificate id..."
export ENGINE_CERT_ID=$(jq -n "${engine_certs}" |
    jq --arg KEYPAIR_ALIAS_NAME "${keypair_alias}" \
        '.items[] | select(.alias==$KEYPAIR_ALIAS_NAME and .keyPair==true) | .id')
if test $? -ne 0; then
  beluga_error "Processing the TrustedCertificates json was unsuccessful."
  beluga_error "The response was: ${ENGINE_CERT_ID}"
  exit 1
else
  beluga_log "Successfully located the correct certificate id: ${ENGINE_CERT_ID}"
fi

beluga_log "Retrieving all of the engines..."
engines=$(get_engines)
if test $? -ne 0; then
    beluga_error "Retrieving the Engines was unsuccessful."
    beluga_error "The response was: ${engines}"
    exit 1
else
  beluga_log "Successfully retrieved all of the engines"
fi

# Retrieve the Engine ID for name.
beluga_log "Processing all of the engines to find the id for the engine with the name: ${ENGINE_NAME}..."
ENGINE=$(jq -n "${engines}" | jq --arg ENGINE_NAME "${ENGINE_NAME}" '.items[] | select(.name==$ENGINE_NAME)')
ENGINE_ID=$(jq -n "${ENGINE}" | jq -r ".id")

# If engine doesn't exist, then create new engine.
if test -z "${ENGINE_ID}" || test "${ENGINE_ID}" = 'null'; then

  beluga_log "The engine ${ENGINE_NAME} doesn't exist. Creating engine..."

  new_engine_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/new-engine.json)

  NEW_ENGINE=$(make_api_request -X POST -d "${new_engine_payload}" "${PINGACCESS_ADMIN_API_ENDPOINT}/engines")
  if test $? -ne 0; then
    beluga_error "Creating the engine ${ENGINE_NAME} was unsuccessful."
    beluga_error "The response was: ${NEW_ENGINE}"
    exit 1
  else
    beluga_log "Successfully created a new engine"
  fi

  ENGINE_ID=$(jq -n "${NEW_ENGINE}" | jq '.id')
else

  # PDO-2025 - Update the existing engine to ensure:
  # 1) The selectedCertificateId matches the CONFIG QUERY listener key pair
  # 2) The configReplicationEnabled flag is set to true
  beluga_log "The engine ${ENGINE_NAME} already exists.  Update the configuration to ensure it matches with expectations."

  # Gather the existing keys and export so they'll get injected
  # into the json template
  export EXISTING_PUBLIC_ENGINE_KEYS=$(echo "${ENGINE}" | jq -r ".keys")
  update_engine_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/update-engine.json)
  unset EXISTING_PUBLIC_ENGINE_KEYS

  updated_engine=$(make_api_request -X PUT -d "${update_engine_payload}" "${PINGACCESS_ADMIN_API_ENDPOINT}/engines/${ENGINE_ID}")
  if test $? -ne 0; then
    beluga_error "Updating engine ${ENGINE_ID} with the name ${ENGINE_NAME} was unsuccessful."
    beluga_error "The payload was: ${update_engine_payload}"
    beluga_error "The response was: ${updated_engine}"
    exit 1
  else
    beluga_log "Successfully updated the engine: ${ENGINE_NAME}"
    beluga_log "Configuration replication re-enabled for: ${ENGINE_NAME}"
  fi
fi

# Download Engine Configuration.
beluga_log "Retrieving configuration for ${ENGINE_NAME}..."
make_api_request_download -X POST \
    "${PINGACCESS_ADMIN_API_ENDPOINT}/engines/${ENGINE_ID}/config" -o engine-config.zip
test $? -ne 0 && exit 1

# Validate zip.
beluga_log "validating downloaded config archive"
if test $(unzip -t engine-config.zip &> /dev/null; echo $?) -ne 0; then
  beluga_error "Failure retrieving config admin zip for engine"
  exit 1
fi

beluga_log "extracting config files to conf folder"
unzip -o engine-config.zip -d "${OUT_DIR}"/instance
chmod 400 "${OUT_DIR}"/instance/conf/pa.jwk

if is_secondary_cluster; then
  if ! sed -i "s/engine.admin.configuration.port.*/engine.admin.configuration.port=${CLUSTER_CONFIG_PORT}/g" /opt/out/instance/conf/bootstrap.properties; then
    beluga_error "Failed to update admin port"
    exit 1
  fi
  if ! sed -i "s/engine.admin.configuration.host.*/engine.admin.configuration.host=${CLUSTER_PUBLIC_HOSTNAME}/g" /opt/out/instance/conf/bootstrap.properties; then
    beluga_error "Failed to update admin host"
    exit 1
  fi
fi

beluga_log "cleaning up zip"
rm engine-config.zip

beluga_log "Finished add engine script"
