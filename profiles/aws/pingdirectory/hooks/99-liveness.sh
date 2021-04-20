#!/usr/bin/env sh
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

# shellcheck source=/dev/null
test -f "${CONTAINER_ENV}" && . "${CONTAINER_ENV}"

beluga_log "Test LDAP docker container liveness check connection"
# shellcheck disable=SC2086
ldapsearch \
  --dontWrap \
  --terse \
  --suppressPropertiesFileComment \
  --noPropertiesFile \
  --operationPurpose "Docker container liveness check" \
  --port "${LDAPS_PORT}" \
  --useSSL \
  --trustAll \
  --baseDN "" \
  --searchScope base "(&)" 1.1 \
  2>/dev/null || exit 1

beluga_log "Test LDAP ou=admins,o=platformconfig connection"
# shellcheck disable=SC2086
ldapsearch \
  --operationPurpose "Checking ou=admins,o=platformconfig connection" \
  --noPropertiesFile \
  --terse \
  --hostname "pingdirectory" \
  --port "1389" \
  --baseDN "ou=admins,o=platformconfig" \
  --searchScope base "(&)" \
  2>/dev/null || exit 1