#!/bin/bash

##################################################################
# Common variables
##################################################################
[[ ${CI_COMMIT_REF_SLUG} != master ]] && export ENVIRONMENT=-${CI_COMMIT_REF_SLUG}

FQDN=${ENVIRONMENT}.${TENANT_DOMAIN}

# Common
LOGS_CONSOLE=https://logs.${TENANT_DOMAIN}

# Pingdirectory
PINGDIRECTORY_CONSOLE=https://pingdataconsole${FQDN}/console

# Pingfederate
# admin services:
PINGFEDERATE_CONSOLE=https://pingfederate-admin${FQDN}/pingfederate/app
PINGFEDERATE_API=https://pingfederate-admin${FQDN}/pingfederate/app/pf-admin-api/api-docs

# runtime services:
PINGFEDERATE_AUTH_ENDPOINT=https://pingfederate${FQDN}
PINGFEDERATE_OAUTH_PLAYGROUND=https://pingfederate${FQDN}/OAuthPlayground

# Pingaccess
# admin services:
PINGACCESS_CONSOLE=https://pingaccess-admin${FQDN}
PINGACCESS_API=https://pingaccess-admin${FQDN}/pa-admin-api/v3/api-docs

# runtime services:
PINGACCESS_RUNTIME=https://pingaccess${FQDN}

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