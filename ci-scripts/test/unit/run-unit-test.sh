#!/bin/bash

TEST_DIR="${1}"
ENV_VARS_FILE="${2}"

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. "${SCRIPT_HOME}"/../../common.sh "${ENV_VARS_FILE}"
. "${SCRIPT_HOME}"/../../../utils.sh

if test ! -z "${SKIP_TESTS}"; then
  log "The following tests will be skipped: ${SKIP_TESTS}"
fi

prepareShunit

EXIT_CODE=0

# This variable will need to change when the shunit version changes
export SHUNIT_PATH="${PROJECT_DIR}/ci-scripts/test/shunit/shunit2-2.1.x/shunit2"
for SCRIPT in $(find "${SCRIPT_HOME}/${TEST_DIR}" -name \*.sh | sort); do
  log "Running unit test ${SCRIPT}"
  "${SCRIPT}"

  TEST_RESULT=$?
  log "Test result: ${TEST_RESULT}"
  echo

  test "${TEST_RESULT}" -ne 0 && EXIT_CODE=1
done

if test "${EXIT_CODE}" -eq 0; then
  log "Test Summary: All unit tests in directory ${TEST_DIR} completed successfully"
  echo
else
  log "Test Summary: One or more unit tests in directory ${TEST_DIR} failed"
  echo
fi

exit "${EXIT_CODE}"
