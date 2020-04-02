#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. "${SCRIPT_HOME}"/../../common.sh "${1}"

if "${DEV_TEST_ENV}" = 'true'; then
  if pgrep -f docker > /dev/null; then
    docker run --rm pingidentity/ldap-sdk-tools ldapsearch \
      --hostname "${PINGDIRECTORY_ADMIN}" \
      --port 636 \
      --bindDN 'cn=administrator' \
      --bindPassword '2FederateM0re' \
      --useSSL \
      --trustAll \
      --baseDN "cn=config" \
      --searchScope base "(&)" 1.1
  else
    echo 'Docker daemon required to run this test in dev environments'
  fi
else
  /opt/tools/ldapsearch \
    --hostname "${PINGDIRECTORY_ADMIN}" \
    --port 636 \
    --bindDN 'cn=administrator' \
    --bindPassword '2FederateM0re' \
    --useSSL \
    --trustAll \
    --baseDN "cn=config" \
    --searchScope base "(&)" 1.1
fi

exit ${?}