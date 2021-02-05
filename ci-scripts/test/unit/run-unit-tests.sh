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

# This variable will need to change when the shunit version changes
export SHUNIT_PATH="${PROJECT_DIR}/ci-scripts/test/shunit/shunit2-2.1.x/shunit2"

execute_test_scripts() {

  local test_directory="${1}"
  local hooks_dir="${2}"
  local templates_dir="${3}"
  local regex="${4}"
  local test_file_failures=0

  # Provide env vars pointing to the current
  # scripts and templates being tested
  export HOOKS_DIR="${hooks_dir}"
  export TEMPLATES_DIR="${templates_dir}"

  for SCRIPT in $(find ${test_directory} -print | grep -E ${regex} | sort); do
    log "Running unit test: ${SCRIPT}"
    "${SCRIPT}"

    test_result=$?
    log "Test result: ${test_result}"
    echo

    # Calculate and track the combined results of all tests
    test_file_failures=$((${test_file_failures} + ${test_result}))
  done

  unset HOOKS_DIR
  unset TEMPLATES_DIR

  return ${test_file_failures}
}

# Pass in a regex to selectively execute
# the tests in the designated subdirectory
# and skip other support scripts, etc.
log "Running test scripts..."

# To be found by the regex, scripts must be:
# - under the ci-script-tests, common or ping-prefixed directories (no matter how deep)
# - must be prefixed with at least a 2-digit number to be found and must end with .sh
execute_test_scripts "${SCRIPT_HOME}/${TEST_DIR}" \
                     "${PROJECT_DIR}/profiles/aws/${TEST_DIR}/hooks" \
                     "${PROJECT_DIR}/profiles/aws/${TEST_DIR}/templates" \
                     '(ci-script-tests|common|ping[a-zA-Z-]*)\/.*\/[0-9][0-9]+.*\.sh'
exit_code=$?

NO_COLOR='\033[0m' # No Color
if test ${exit_code} -eq 0; then
  GREEN='\033[0;32m'
  # Use printf to print in color
  printf '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n'
  printf "Unit Test Summary: ${GREEN}All unit tests in ${TEST_DIR} completed successfully ${NO_COLOR}\n"
  printf '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n'
else
  RED='\033[0;31m'
  # Use printf to print in color
  printf '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n'
  printf "Unit Test Summary: ${RED} ${exit_code} Unit test script file(s) failed under: ${TEST_DIR} ${NO_COLOR}\n"
  printf '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n'
fi

echo
exit ${exit_code}
