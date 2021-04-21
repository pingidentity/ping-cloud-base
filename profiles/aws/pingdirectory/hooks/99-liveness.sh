#!/usr/bin/env sh
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
  --hostname "${HOSTNAME}" \
  --port "${LDAPS_PORT}" \
  --useSSL \
  --trustAll \
  --baseDN "" \
  --searchScope base "(&)" 1.1 || exit 1

ldapsearch \
  --operationPurpose "Checking ou=clients,o=appintegrations" \
  --hostname "${HOSTNAME}" \
  --port "${LDAPS_PORT}" \
  --baseDN "ou=clients,o=appintegrations" \
  --searchScope base "(&)" || exit 1

# vars=""
# if [[ "${PF_PD_BIND_USESSL}" = true ]]; then
#   vars="--useSSL --trustAll --port 5678"
# else
#   vars="--port 1389"
# fi

ldapsearch \
  --noPropertiesFile \
  --port 1389 \
  --operationPurpose "Checking ou=admins,o=platformconfig connection" \
  --hostname "${HOSTNAME}" \
  --baseDN "ou=admins,o=platformconfig" \
  --filter "(uid={0})" \
  2>/dev/null || exit 1