#!/usr/bin/env sh

#####################################################################################################################
# DOCS: More documentation on certificate management for PingDirectory can be found here:                           #
# https://confluence.pingidentity.com/x/Y6nOCQ                                                                      #
#                                                                                                                   #
# Original note from Savitha, left here for posterity                                                               #
# NOTE: PD comes with a tool called replace-certificate to replace its certificates, but replace-certificate will   #
# bark if the root CA cert or any intermediate certs are not found in the CA bundle. So it'll only work for the LE  #
# production server. The LE staging cert doesn't end with a self-signed root certificate. It is signed by issuers   #
# that are not in the CA bundle. For these reasons, we'll use keytool for all of the following commands because it  #
# provides a more generic solution.                                                                                 #
#####################################################################################################################

# Configure line-by-line logging if the variable VERBOSE is true.
${VERBOSE:-false} && set -x

# Source some utilities.
. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

# We are working with two keystores - cert-manager ('CM') and PingDirectory ('PD')
# The keystore, cert, key are all mounted from a k8s secret at this location
CM_KEYSTORE_FILE="${SECRETS_DIR}/certs/keystore.p12"
CM_CERT_FILE="${SECRETS_DIR}/certs/tls.crt"

# The cert-manager alias is 1, it appears to be set by default
CM_CERT_ALIAS='1'
CM_KEYSTORE_PW="${ACME_CERT_KEYSTORE_PASSWORD:-2FederateM0re}"
CM_KEYSTORE_TYPE='PKCS12'

# The default alias used by PD
PD_CERT_ALIAS='server-cert'

# This is the keystore default location within PD
PD_KEYSTORE_FILE="${SERVER_ROOT_DIR}/config/keystore"
PD_KEYSTORE_PW_FILE="${SERVER_ROOT_DIR}/config/keystore.pin"
PD_KEYSTORE_PW_FILE_DECRYPTED="${PD_KEYSTORE_PW_FILE}.decrypted"
PD_KEYSTORE_TYPE='JKS'

PD_TRUSTSTORE_FILE="${SERVER_ROOT_DIR}/config/truststore"
PD_TRUSTSTORE_PW_FILE="${PD_TRUSTSTORE_FILE}.pin"
PD_TRUSTSTORE_PW_FILE_DECRYPTED="${PD_TRUSTSTORE_PW_FILE}.decrypted"

# Remove leftover decrypted files
cleanup() {
  rm -f "${PD_KEYSTORE_PW_FILE_DECRYPTED}"
  rm -f "${PD_TRUSTSTORE_PW_FILE_DECRYPTED}"
}

# Overwrite the server-cert alias in the keystore with latest cert from cert-manager
import_source_cert_into_server_keystore() {
  beluga_log "Importing alias ${CM_CERT_ALIAS} from ${CM_KEYSTORE_FILE} into server keystore"
  keytool -importkeystore -noprompt \
      -srckeystore "${CM_KEYSTORE_FILE}" \
      -srcstoretype "${CM_KEYSTORE_TYPE}" \
      -srcstorepass "${CM_KEYSTORE_PW}" \
      -srcalias "${CM_CERT_ALIAS}" \
      -destkeystore "${PD_KEYSTORE_FILE}" \
      -deststoretype "${PD_KEYSTORE_TYPE}" \
      -deststorepass:file "${PD_KEYSTORE_PW_FILE_DECRYPTED}" \
      -destkeypass:file "${PD_KEYSTORE_PW_FILE_DECRYPTED}" \
      -destalias "${PD_CERT_ALIAS}"
}

# Remove the old alias server-cert from the truststore
delete_cert_alias_from_server_truststore() {
  beluga_log "Deleting alias ${PD_CERT_ALIAS} from server truststore, if it exists"

  keytool -list -noprompt \
      -keystore "${PD_TRUSTSTORE_FILE}" \
      -storepass:file "${PD_TRUSTSTORE_PW_FILE_DECRYPTED}" \
      -alias "${PD_CERT_ALIAS}"

  if test $? -eq 0; then
    keytool -delete -noprompt \
        -keystore "${PD_TRUSTSTORE_FILE}" \
        -storepass:file "${PD_TRUSTSTORE_PW_FILE_DECRYPTED}" \
        -alias "${PD_CERT_ALIAS}"
  fi
}

# Import server-cert into the truststore
import_source_cert_into_server_truststore() {
  beluga_log "Importing certificate from ${CM_CERT_FILE} as alias ${PD_CERT_ALIAS} into the server truststore"
  keytool -import -noprompt \
      -trustcacerts \
      -file "${CM_CERT_FILE}" \
      -keystore "${PD_TRUSTSTORE_FILE}" \
      -storepass:file "${PD_TRUSTSTORE_PW_FILE_DECRYPTED}" \
      -keypass:file "${PD_TRUSTSTORE_PW_FILE_DECRYPTED}" \
      -alias "${PD_CERT_ALIAS}"
}

# Get all of the fingerprints for the cert chain and put them together,
# then create a new sha based on the combined fingerprint and return it
get_fingerprint_sha() {
  keystore=$1
  alias=${PD_CERT_ALIAS}

  if [ "${keystore}" = "${CM_KEYSTORE_FILE}" ]; then
    pass_arg="--keystore-password ${CM_KEYSTORE_PW}"
    alias=${CM_CERT_ALIAS}
  fi

  full_cert=$(manage-certificates list-certificates \
                --keystore "${keystore}" \
                --alias "${alias}" ${pass_arg} 2>&1)

  if [ $? != 0 ]; then
    beluga_error "Error running list certificate"
    exit 1
  fi

  # Grab all fingerprints
  all_shas=$(echo "${full_cert}" | grep 'SHA-256 Fingerprint:')
  # Remove newlines
  all_shas=$(echo "${all_shas}" | tr -d '\n')
  # Calculate SHA of all fingerprints
  final_sha=$(echo "${all_shas}" | sha256sum | awk '{print $1}')

  echo "${final_sha}"
}

# Return 0 if certs are equal, 1 otherwise
certs_equal() {
  pd_sha=$(get_fingerprint_sha "${PD_KEYSTORE_FILE}")
  cm_sha=$(get_fingerprint_sha "${CM_KEYSTORE_FILE}")

  if [ "${pd_sha}" != "${cm_sha}" ]; then
    beluga_warn "CM and PD keystore cert alias 'server-cert' are NOT the same"
    return 1
  else
    return 0
  fi
}

# Remove/add from truststore and replace in keystore the new certificate
replace_server_cert() {

  # The keystore and truststore password files are encrypted on the server's file system and must first be decrypted.
  decrypt_file "${PD_KEYSTORE_PW_FILE}"
  decrypt_file "${PD_TRUSTSTORE_PW_FILE}"

  import_source_cert_into_server_keystore

  delete_cert_alias_from_server_truststore
  import_source_cert_into_server_truststore

  display_all_certs
  cleanup
  beluga_log "Certificate change complete!"
}

# Do an initial sanity check - exit non-zero if any checks fail
readiness_check() {
  beluga_log "Checking all required files are present..."
  # Do both the CM keystore and cert files exist?
  if [ ! -f "${CM_KEYSTORE_FILE}" ] || [ ! -f "${CM_CERT_FILE}" ]; then
    beluga_error "Missing ${CM_KEYSTORE_FILE} and/or ${CM_CERT_FILE} - check mounted secrets"
    return 1
  fi

  # Do all of the PD keystores and truststore exist?
  if [ ! -f "${PD_KEYSTORE_FILE}" ] || [ ! -f "${PD_KEYSTORE_PW_FILE}" ] || [ ! -f "${PD_TRUSTSTORE_FILE}" ] || [ ! -f "${PD_TRUSTSTORE_PW_FILE}" ]; then
    beluga_error "Missing one of the following PingDirectory keystore/truststore files: ${PD_KEYSTORE_FILE}, ${PD_KEYSTORE_PW_FILE}, ${PD_TRUSTSTORE_FILE}, or ${PD_TRUSTSTORE_PW_FILE}"
    return 1
  fi
}

# Display the current state of the CM keystore, PD keystore/truststore
# Only print alias name and fingerprint to prevent from being too noisy
display_all_certs() {
  beluga_log "--> Certificate info - all certificates currently in the cert-manager keystore:"
  manage-certificates list-certificates \
                --keystore "${CM_KEYSTORE_FILE}" \
                --keystore-password "${CM_KEYSTORE_PW}" \
                2> /dev/null | grep -E '(Alias|Fingerprint)'

  beluga_log "--> Certificate info - all certificates currently in the PingDirectory keystore:"
  manage-certificates list-certificates \
                --keystore "${PD_KEYSTORE_FILE}" \
                2> /dev/null | grep -E '(Alias|Fingerprint)'

  beluga_log "--> Certificate info - all certificates currently in the PingDirectory truststore:"
  manage-certificates list-certificates \
                --keystore "${PD_TRUSTSTORE_FILE}" \
                2> /dev/null | grep -E '(Alias|Fingerprint)'
}

# Check upon initial startup that we are still using the newest cert provided by cert-manager,
# and only replace if the certs don't match
initial_startup_check() {
  if ! readiness_check; then
    # Terminate hook as required certificates must be present on initial startup
    exit 1
  fi

  display_all_certs

  beluga_log "Checking if PD started with a different cert than provided by cert-manager currently..."

  if ! certs_equal; then
    beluga_warn "Started with a different certificate than cert-manager provides, removing old cert and adding cert-manager..."
    replace_server_cert
  else
    beluga_log "Certificate check done, no diff for alias ${PD_CERT_ALIAS}"
  fi
}

# Loop forever and check if the mounted keystore has changed
# If it has, run replace_server_cert
watch_for_cert_update() {
  # check interval, in seconds - run less often in case there is performance impact
  # of running manage-certificates frequently
  check_interval=60

  beluga_log "Perpetually watching ${CM_KEYSTORE_FILE} for changes..."
  while true; do
    sleep $check_interval;

    if ! readiness_check; then
      beluga_warn "Missing required certificate(s) will keep trying until certificate(s) are present"
      continue
    else
      if ! certs_equal; then
        display_all_certs
        beluga_log "${CM_KEYSTORE_FILE} was changed, running replace-certificate script"
        replace_server_cert
      fi
    fi
  done
}

# See if the cert differs from cert-manager on initial startup
initial_startup_check

# Start a background job to perpetually check if the license changes and update it
watch_for_cert_update &
