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

beluga_log "Test LDAP ou=accessgrants,o=appintegrations connection"
ldapsearch \
  ou=accessgrants,o=appintegrations \
  2>/dev/null || exit 1

beluga_log "Test LDAP ou=clients,o=appintegrations connection"
ldapsearch \
  ou=clients,o=appintegrations \
  2>/dev/null || exit 1

beluga_log "Test LDAP ou=authsessions,o=appintegrations connection"
ldapsearch \
  ou=authsessions,o=appintegrations \
  2>/dev/null || exit 1

beluga_log "Test LDAP uid=pingfederate,ou=devopsaccount,o=platformconfig connection"
ldapsearch \
  uid=pingfederate,ou=devopsaccount,o=platformconfig \
  2>/dev/null || exit 1

beluga_log "Test LDAP ou=admins,o=platformconfig connection"
ldapsearch \
  ou=admins,o=platformconfig \
  2>/dev/null || exit 1