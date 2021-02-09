#!/bin/bash

# Source the script we're testing
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null

testBelugaLogging() {

  msg="my message"

  # Verify the default behavior
  log_msg=$(beluga_log "${msg}")
  assertEquals 0 ${?}
  assertContains "${log_msg}" "${msg}"
  assertContains "${log_msg}" "INFO"

  # Verify adding a different log_level
  log_msg=$(beluga_log "${msg}" "WARN")
  assertEquals 0 ${?}
  assertContains "${log_msg}" "${msg}"
  assertContains "${log_msg}" "WARN"
}

# load shunit
. ${SHUNIT_PATH}
