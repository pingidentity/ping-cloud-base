#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/11-remove-image-scripts.sh > /dev/null

testFileExists() {
  touch /tmp/remove_me.sh
  response=$(delete_file "/tmp/remove_me.sh")
  assertEquals "delete_file should always return 0" 0 $?

  message="INFO Checking for /tmp/remove_me.sh"
  assertContains "If the /tmp/remove_me.sh file exists, this function should print the message" "${response}" "${message}"

  message="INFO Successfully deleted /tmp/remove_me.sh"
  assertContains "If the /tmp/remove_me.sh file exists, this function should print the message" "${response}" "${message}"
}

testFileAbsent() {
  # Make sure it's gone
  rm -f /tmp/remove_me.sh

  response=$(delete_file "/tmp/remove_me.sh")
  assertEquals "delete_file should always return 0" 0 $?

  message="INFO Checking for /tmp/remove_me.sh"
  assertContains "If the /tmp/remove_me.sh file exists, this function should print the message" "${response}" "${message}"

  message="INFO /tmp/remove_me.sh not found"
  assertContains "If the /tmp/remove_me.sh file exists, this function should print the message" "${response}" "${message}"
}

# load shunit
. ${SHUNIT_PATH}
