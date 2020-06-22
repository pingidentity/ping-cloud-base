#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

if test "${DEV_TEST_ENV}" = 'true'; then
  if pgrep -f docker > /dev/null; then
    docker run --rm pingidentity/ldap-sdk-tools ldapsearch \
      --terse \
      --hostname "${PINGDIRECTORY_ADMIN}" \
      --port "${PD_SEED_LDAPS_PORT}" \
      --bindDN 'cn=administrator' \
      --bindPassword '2FederateM0re' \
      --useSSL \
      --trustAll \
      --baseDN "cn=config" \
      --searchScope base "(&)" 1.1
  else
    log 'Docker daemon required to run this test in dev environments'
  fi
else
  /opt/tools/ldapsearch \
    --terse \
    --hostname "${PINGDIRECTORY_ADMIN}" \
    --port "${PD_SEED_LDAPS_PORT}" \
    --bindDN 'cn=administrator' \
    --bindPassword '2FederateM0re' \
    --useSSL \
    --trustAll \
    --baseDN "cn=config" \
    --searchScope base "(&)" 1.1
fi

exit ${?}