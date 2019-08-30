#!/bin/sh

##################################################################
# Common variables
##################################################################
PINGDIRECTORY_CONSOLE=https://pingdataconsole.${TENANT_DOMAIN}/console

PINGFEDERATE_CONSOLE=https://pingfederate.${TENANT_DOMAIN}/pingfederate/app
PINGFEDERATE_AUTH_ENDPOINT=https://pingfederate.${TENANT_DOMAIN}
PINGFEDERATE_OAUTH_PLAYGROUND=https://pingfederate.${TENANT_DOMAIN}/OAuthPlayground

PING_ACCESS_CONSOLE=https://pingaccess.${TENANT_DOMAIN}

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
  wget --spider --no-check-certificate $1 >/dev/null 2>&1
  exit_code=$?
  log "Command exit code: ${exit_code}"
  return ${exit_code}
}

##########################################################################
# Retries a command with exponential backoff.
#
# Arguments:
#   $1 -> The maximum number of attempts
#   $2 -> Initial timeout; successive backoffs will double the timeout
#
# Returns:
#   Command's exit code.
##########################################################################
retryWithBackoff() {
  max_attempts=$1
  timeout=$2
  command=$3

  attempt=0
  exit_code=0

  while [[ ${attempt} < ${max_attempts} ]]; do
    "${command}"
    exit_code=$?

    if [[ ${exit_code} == 0 ]]; then
      break
    fi

    log "Failed attempt ${attempt} - retrying in ${timeout} seconds"
    sleep ${timeout}

    attempt=$((attempt + 1))
    timeout=$((timeout * 2))
  done

  log "Command ${command} exit code: ${exit_code}"
  return ${exit_code}
}