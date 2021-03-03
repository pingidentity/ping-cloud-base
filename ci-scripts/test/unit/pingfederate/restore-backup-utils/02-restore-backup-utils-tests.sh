#!/bin/bash

# Source the script we're testing
# Suppress env vars noise in the test output
. "${HOOKS_DIR}"/utils.lib.sh > /dev/null
. "${HOOKS_DIR}"/util/restore-backup-utils.sh > /dev/null

mktemp() {
  return 0
}

oneTimeSetUp() {
  export VERBOSE=false
  export SERVER_ROOT_DIR=/opt/out/instance
}

oneTimeTearDown() {
  unset VERBOSE
  unset SERVER_ROOT_DIR
}

testServerMasterKeyPath() {
  # unset for this particular test
  unset MASTER_KEY_PATH
  local expected_master_key_path="${SERVER_ROOT_DIR}/server/default/data/pf.jwk"

  set_script_variables
  assertEquals 0 ${?}

  assertEquals "Invalid master key path for PingFederate: ${MASTER_KEY_PATH}" "${expected_master_key_path}" "${MASTER_KEY_PATH}"
  assertEquals "Invalid DATA_BACKUP_FILE_NAM: ${DATA_BACKUP_FILE_NAME}" "latest.zip" "${DATA_BACKUP_FILE_NAME}"
}

testServerDeployerPath() {
  # unset for this particular test
  unset DEPLOYER_PATH
  local expected_drop_in_deployer_path="${SERVER_ROOT_DIR}/server/default/data/drop-in-deployer"

  set_script_variables
  assertEquals 0 ${?}

  assertEquals "Invalid deployer path for PingFederate." "${expected_drop_in_deployer_path}" "${DEPLOYER_PATH}"
  assertEquals "Invalid DATA_BACKUP_FILE_NAM: ${DATA_BACKUP_FILE_NAME}" "latest.zip" "${DATA_BACKUP_FILE_NAME}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
