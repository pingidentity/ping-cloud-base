#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/restore-backup-utils.sh > /dev/null

mktemp() {
  return 0
}

setUp() {
  # unset for these tests
  unset DATA_BACKUP_FILE_NAME
}

oneTimeSetUp() {
  export VERBOSE=false
  export SERVER_ROOT_DIR=/opt/out/instance

}

oneTimeTearDown() {
  unset VERBOSE
  unset SERVER_ROOT_DIR
  unset BACKUP_FILE_NAME
}

testBackupFileNameWhenSet() {
  local test_pf_backup_file_name="data-mm-dd-yyyy.hh.mm.ss.zip"

  # Mock BACKUP_FILE_NAME variable, script uses this variable as the desired file to restore
  # BACKUP_FILE_NAME is set with extra spaces, script is expected to trim before assigning to
  # DATA_BACKUP_FILE_NAME variable.
  export BACKUP_FILE_NAME="${test_pf_backup_file_name}          "

  set_script_variables
  assertEquals 0 ${?}

  assertEquals "${test_pf_backup_file_name}" "${DATA_BACKUP_FILE_NAME}"
}

testBackupFileNameWhenNotSet() {
  unset BACKUP_FILE_NAME

  set_script_variables
  assertEquals 0 ${?}

  assertNull "BACKUP_FILE_NAME is reserved by user and script shouldn't set." "${BACKUP_FILE_NAME}"
  assertEquals "BACKUP_FILE_NAME was not set, therefore script should look to restore latest.zip from s3." \
    "latest.zip" "${DATA_BACKUP_FILE_NAME}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
