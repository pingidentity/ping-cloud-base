#!/bin/bash

TEST_DIR="${1}"
ENV_VARS_FILE="${2}"

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. "${SCRIPT_HOME}"/../../common.sh "${ENV_VARS_FILE}"

# Configure aws and kubectl, unless skipped
configure_aws
configure_kube

if test ! -z "${SKIP_TESTS}"; then
  log "The following tests will be skipped: ${SKIP_TESTS}"
fi

prepareShunit

EXIT_CODE=0

# This variable will need to change when the shunit version changes
export SHUNIT_PATH="${PROJECT_DIR}/ci-scripts/test/shunit/shunit2-2.1.x/shunit2"
for SCRIPT in $(find "${SCRIPT_HOME}/${TEST_DIR}" -name \*.sh | sort); do
  log "Running integration test ${SCRIPT}"
  "${SCRIPT}" "${ENV_VARS_FILE}"

  TEST_RESULT=$?
  log "Test result: ${TEST_RESULT}"
  echo

  test "${TEST_RESULT}" -ne 0 && EXIT_CODE=1
done

if test "${EXIT_CODE}" -eq 0; then
  log "Test Summary: All tests in directory ${TEST_DIR} completed successfully"
  echo
else
  log "Test Summary: One or more tests in directory ${TEST_DIR} failed"
  echo
fi

exit "${EXIT_CODE}"