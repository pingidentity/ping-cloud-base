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

vars=""
if [[ "${PF_PD_BIND_USESSL}" = true ]]; then
  vars="--useSSL --trustAll --port 5678"
else
  vars="--port 1389"
fi

ldapsearch \
  --noPropertiesFile \
  --terse \
  ${vars} \
  --operationPurpose "Checking ou=admins,o=platformconfig connection" \
  --hostname "${HOSTNAME}" \
  --baseDN "ou=admins,o=platformconfig" \
  --searchScope base "(&)" \
  2>/dev/null || exit 1