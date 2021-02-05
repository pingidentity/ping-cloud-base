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


# This variable will need to change when the shunit version changes
export SHUNIT_PATH="${PROJECT_DIR}/ci-scripts/test/shunit/shunit2-2.1.x/shunit2"

execute_test_scripts() {

  local test_directory="${1}"
  local regex="${2}"
  local test_file_failures=0

  for SCRIPT in $(find ${test_directory} -print | grep -E ${regex} | sort); do
    log "Running integration test: ${SCRIPT}"
    "${SCRIPT}" "${ENV_VARS_FILE}"

    test_result=$?
    log "Test result: ${test_result}"
    echo

    # Calculate and track the combined results of all tests
    test_file_failures=$((${test_file_failures} + ${test_result}))

  done

  return ${test_file_failures}
}

log "Running prerequisite scripts..."

# Pass in a regex to selectively execute
# the tests in the prerequisites subdirectory
# and skip other support scripts, etc.
# The prerequisites scripts/tests are meant to help
# with issues like DNS propagation delay.
# These tests must succeed before the other
# integration tests can run.

# To be found by the regex, scripts must be:
# - under the ci-script-tests, common or ping-prefixed directories (no matter how deep)
# - must be prefixed with at least a 2-digit number to be found and must end with .sh
execute_test_scripts "${SCRIPT_HOME}/${TEST_DIR}/prerequisites" '(chaos|ping[a-zA-Z-]*|monitoring)\/prerequisites\/[0-9][0-9]+.*\.sh'
exit_code=$?

NO_COLOR='\033[0m' # No Color
if test ${exit_code} -eq 0; then
  GREEN='\033[0;32m'
  # Use printf to print in color
  printf '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n'
  printf "Prerequisite Test Summary: ${GREEN}All prerequisite tests in ${TEST_DIR} completed successfully ${NO_COLOR}\n"
  printf '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n'
else
  RED='\033[0;31m'
  # Use printf to print in color
  printf '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n'
  printf "Prerequisite Test Summary: ${RED} ${exit_code} Prerequisite test script files(s) failed under: ${TEST_DIR} ${NO_COLOR}\n"
  printf '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n'

  # Exit at this point.  If the prerequisites
  # are not met, then the tests below will
  # fail generating a lot of noise when
  # the issue is likely more fundamental.
  exit ${exit_code}
fi

# Pass in a regex to selectively execute
# the tests in the designated subdirectory
# and skip other support scripts, etc.
log "Running test scripts..."

# To be found by the regex, scripts must be:
# - under the ci-script-tests, common or ping-prefixed directories (no matter how deep)
# - must be prefixed with at least a 2-digit number to be found and must end with .sh
execute_test_scripts "${SCRIPT_HOME}/${TEST_DIR}" '(chaos|ping[a-zA-Z-]*|monitoring)\/[0-9][0-9]+.*\.sh'
exit_code=$?

if test ${exit_code} -eq 0; then
  GREEN='\033[0;32m'
  # Use printf to print in color
  printf '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n'
  printf "Test Summary: ${GREEN}All integration tests in ${TEST_DIR} completed successfully ${NO_COLOR}\n"
  printf '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n'
else
  RED='\033[0;31m'
  # Use printf to print in color
  printf '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n'
  printf "Test Summary: ${RED} ${exit_code} Integration test script file(s) failed under: ${TEST_DIR} ${NO_COLOR}\n"
  printf '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n'
fi

echo
exit ${exit_code}
