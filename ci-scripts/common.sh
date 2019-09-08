#!/bin/bash

##################################################################
# Common variables
##################################################################
FQDN=${ENVIRONMENT}.${TENANT_DOMAIN}
PINGDIRECTORY_CONSOLE=https://pingdataconsole${FQDN}/console

PINGFEDERATE_CONSOLE=https://pingfederate${FQDN}/pingfederate/app
PINGFEDERATE_AUTH_ENDPOINT=https://pingfederate${FQDN}
PINGFEDERATE_OAUTH_PLAYGROUND=https://pingfederate${FQDN}/OAuthPlayground

PING_ACCESS_CONSOLE=https://pingaccess${FQDN}

LOGS_CONSOLE=https://logs.${TENANT_DOMAIN}

##########################################################################
# Echoes a message prepended with the current time
#
# Arguments
#   $1 -> The message to echo
##########################################################################
log() {
  echo "$(date) $1"
}

##########################################################################
# Tests whether a URL is reachable or not
#
# Arguments:
#   $1 -> The URL
# Returns:
#   0 on success; non-zero on failure
##########################################################################
testUrl() {
  log "Testing URL: $1"
  curl -k $1 >/dev/null 2>&1
  exit_code=$?
  log "Command exit code: ${exit_code}"
  return ${exit_code}
}