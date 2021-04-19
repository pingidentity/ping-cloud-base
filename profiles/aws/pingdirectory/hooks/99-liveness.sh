#!/usr/bin/env sh
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

# shellcheck source=/dev/null
test -f "${CONTAINER_ENV}" && . "${CONTAINER_ENV}"

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

beluga_log "Test LDAP appintegrations Connection"
ldapsearch o=appintegrations && exit 0 || exit 1