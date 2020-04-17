#!/usr/bin/env sh

########################################################################################################################
# Verify that the provided BASE_DN responds to a search request over LDAP.
#
# Arguments
#   ${1} -> The base DN for the search request.
########################################################################################################################
health_check() {
  BASE_DN="${1}"
  ldapsearch \
    --dontWrap \
    --terse \
    --suppressPropertiesFileComment \
    --noPropertiesFile \
    --operationPurpose "Docker container liveness check" \
    --port "${LDAPS_PORT}" \
    --useSSL \
    --trustAll \
    --baseDN "${BASE_DN}" \
    --searchScope base "(&)" 1.1 \
    2>/dev/null
  HEALTH_STATUS=${?}
  echo "Health check for ${BASE_DN} status: ${HEALTH_STATUS}"
  return ${HEALTH_STATUS}
}

# Verify that server is responsive on its LDAP secure port
echo "readiness: verifying root DSE access"
/opt/liveness.sh || exit 1

# Verify that server is responsive on its heartbeat endpoint
echo "readiness: verifying heartbeat endpoint is accessible"
health_check "o=platformconfig" || exit 1

# Verify that post-start initialization is complete on this host
echo "readiness: verifying that post-start initialization is complete on ${HOSTNAME}"
POST_START_INIT_MARKER_FILE="${SERVER_ROOT_DIR}"/config/post-start-init-complete
test -f  "${POST_START_INIT_MARKER_FILE}" && exit 0 || exit 1