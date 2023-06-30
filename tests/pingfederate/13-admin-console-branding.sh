#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# Verify that the PF Admin Console Contains PingOne Branding
# Both in the Tab Tile and Header
testPFAdminConsoleBrandingValues() {

  expected="pf.console.title=Advanced SSO"
  title=$(kubectl exec pingfederate-admin-0 -n "${PING_CLOUD_NAMESPACE}" -c pingfederate-admin -- sh -c \
          "grep pf.console.title /opt/out/instance/bin/run.properties")
  test "${title}" = "${expected}"
  assertEquals "The PingFederate Admin Console Tab Title was ${title} but expected ${expected}" 0 $?

  expected="pf.console.environment=${ENV_TYPE}-${REGION}"
  header_bar=$(kubectl exec pingfederate-admin-0 -n "${PING_CLOUD_NAMESPACE}" -c pingfederate-admin -- sh -c \
              "grep pf.console.environment /opt/out/instance/bin/run.properties")
  test "${header_bar}" = "${expected}"
  assertEquals "The PingFederate Admin Console Header Bar was ${header_bar} but expected ${expected}" 0 $?

}


# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}