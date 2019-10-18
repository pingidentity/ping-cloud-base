#!/bin/bash

########################################################################################################################
# Echoes a message prepended with the current time
#
# Arguments
#   $1 -> The message to echo
########################################################################################################################
log() {
  echo "$(date) $1"
}

########################################################################################################################
# Tests whether a URL is reachable or not
#
# Arguments:
#   $1 -> The URL
# Returns:
#   0 on success; non-zero on failure
########################################################################################################################
testUrl() {
  log "Testing URL: $1"
  curl -k $1 >/dev/null 2>&1
  exit_code=$?
  log "Command exit code: ${exit_code}"
  return ${exit_code}
}

########################################################################################################################
# Generate a self-signed certificate for the provided domain. The subject of the certificate will match the domain name.
# A wildcard SAN (Subject Alternate Name) will be added as well. For example, for the domain ping-aws.com, the subject
# name will be "ping-aws.com" and the SAN "*.ping-aws.com". The base64 representation of the certificate and key will be
# exported in environment variables TLS_CRT_BASE64 and TLS_KEY_BASE64, respectively.
#
# Arguments
#   ${1} -> The name of the domain for which to generate the self-signed certificate.
#
########################################################################################################################
generate_tls_cert() {
  CERTS_DIR=$(mktemp -d)
  cd "${CERTS_DIR}"
  DOMAIN=${1}
  openssl req -x509 -nodes -newkey rsa:2048 -days 3650 -sha256 \
    -out tls.crt -keyout tls.key \
    -subj "/CN=${DOMAIN}" \
    -reqexts SAN -extensions SAN \
    -config <(cat /etc/ssl/openssl.cnf; printf "[SAN]\nsubjectAltName=DNS:*.${DOMAIN}") > /dev/null 2>&1
  export TLS_CRT_BASE64=$(cat tls.crt | base64 | tr -d '\n')
  export TLS_KEY_BASE64=$(cat tls.key | base64 | tr -d '\n')
  cd - > /dev/null
  rm -rf "${CERTS_DIR}"
}

########################################################################################################################
# Generate an RSA key pair. The identity and the base64 representation of the key will exported in environment variables
# IDENTITY_PUB and IDENTITY_KEY_BASE64, respectively.
########################################################################################################################
generate_ssh_key_pair() {
  KEY_PAIR_DIR=$(mktemp -d)
  cd "${KEY_PAIR_DIR}"
  ssh-keygen -q -t rsa -b 2048 -f id_rsa -N ''
  export IDENTITY_PUB=$(cat id_rsa.pub)
  export IDENTITY_KEY_BASE64=$(cat id_rsa | base64 | tr -d '\n')
  cd - > /dev/null
  rm -rf "${KEY_PAIR_DIR}"
}

########################################################################################################################
# Verify that the provided binaries are available.
#
# Arguments
#   ${*} -> The list of required binaries.
########################################################################################################################
check_binaries() {
STATUS=0
	for TOOL in ${*}; do
	  which "${TOOL}" &>/dev/null
    if test ${?} -ne 0; then
      echo "${TOOL} is required but missing"
      STATUS=1
    fi
  done
  return ${STATUS}
}

########################################################################################################################
# Verify that the provided environment variables are set.
#
# Arguments
#   ${*} -> The list of required environment variables.
########################################################################################################################
check_env_vars() {
  STATUS=0
  for NAME in ${*}; do
    VALUE="${!NAME}"
    if test -z "${VALUE}"; then
      echo "${NAME} environment variable must be set"
      STATUS=1
    fi
  done
  return ${STATUS}
}