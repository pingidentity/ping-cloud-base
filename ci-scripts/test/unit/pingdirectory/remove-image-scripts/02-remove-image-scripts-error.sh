#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/11-remove-image-scripts.sh > /dev/null

# Mock a rm failure
rm() {
  return 1
}

testFileCannotBeRemoved() {
  touch /tmp/remove_me.sh
  response=$(delete_file "/tmp/remove_me.sh")
  assertEquals "delete_file should always return 0" 0 $?

  message="INFO Checking for /tmp/remove_me.sh"
  assertContains "If the /tmp/remove_me.sh file exists, this function should print the message" "${response}" "${message}"

  message="ERROR Failed to delete /tmp/remove_me.sh"
  assertContains "If the /tmp/remove_me.sh file exists and we're mocking the rm command, this function should print the message" "${response}" "${message}"

}

# load shunit
. ${SHUNIT_PATH}
