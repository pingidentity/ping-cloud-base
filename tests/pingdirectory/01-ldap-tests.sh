#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

testLdap() {
  log "Using the hostname: ${PINGDIRECTORY_ADMIN} and port: ${PD_SEED_LDAPS_PORT}"
  if test "${IS_BELUGA_ENV}" = 'true' && test "${CI_SERVER}" != "yes"; then
    log "Running process grep and ldapsearch..."
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
    log "Running ldapsearch..."
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

  assertEquals 0 ${?}
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}