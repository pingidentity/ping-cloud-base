#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

URL="${PINGFEDERATE_AUTH_ENDPOINT}/as/token.oauth2?grant_type=client_credentials&scope="
log "Attempting to obtain access token from ${URL}"

curl --max-time 120 --silent -v -k -X POST -u 'PingDirectory:2FederateM0re' "${URL}"
exit ${?}