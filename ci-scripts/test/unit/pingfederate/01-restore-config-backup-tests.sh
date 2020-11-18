#!/bin/bash

# Source the script we're testing
script_to_test="${PROJECT_DIR}"/profiles/aws/pingfederate/hooks/90-restore-backup-s3.sh

setUp() {
  export VERBOSE=false
  export SERVER_ROOT_DIR=/opt/out/instance

  # Mock empty files for script to avoid no directory exist error.
  export HOOKS_DIR=$(mktemp -d)
  touch "${HOOKS_DIR}"/pingcommon.lib.sh
  touch "${HOOKS_DIR}"/utils.lib.sh
}

# Mock this function to avoid sbkn configuration.
initializeSkbnConfiguration() {
  return 0
}

# Mock this function to avoid a skbn call and to control the exit code.
skbnCopy() {
  return 0
}

oneTimeTearDown() {
  unset VERBOSE
  unset SERVER_ROOT_DIR
  unset HOOKS_DIR
  rm -rf "${HOOKS_DIR}"
}

testServerMasterKeyPath() {
  # unset for this particular test
  unset MASTER_KEY_PATH
  local expected_master_key_path="${SERVER_ROOT_DIR}/server/default/data/pf.jwk"

  set_script_variables > /dev/null
  exit_code=${?}

  assertEquals 0 ${exit_code}
  assertEquals "Invalid master key path for PingFederate." "${expected_master_key_path}" "${MASTER_KEY_PATH}"
}

testServerDeployerPath() {
  # unset for this particular test
  unset DEPLOYER_PATH
  local expected_drop_in_deployer_path="${SERVER_ROOT_DIR}/server/default/data/drop-in-deployer"

  set_script_variables > /dev/null
  exit_code=${?}

  assertEquals 0 ${exit_code}
  assertEquals "Invalid deployer path for PingFederate." "${expected_drop_in_deployer_path}" "${DEPLOYER_PATH}"
}

testBackupFileNameWhenSet() {
  local test_pf_backup_file_name="data-mm-dd-yyyy.hh.mm.ss.zip"

  # unset for this particular test
  unset DATA_BACKUP_FILE_NAME

  # Mock BACKUP_FILE_NAME variable, script uses this variable as the desired file to restore
  # BACKUP_FILE_NAME is set with extra spaces, script is expected to trim before assigning to
  # DATA_BACKUP_FILE_NAME variable.
  export BACKUP_FILE_NAME="${test_pf_backup_file_name}          "
  
  set_script_variables > /dev/null
  exit_code=${?}

  assertEquals 0 ${exit_code}
  assertEquals "${test_pf_backup_file_name}" "${DATA_BACKUP_FILE_NAME}"
}

testBackupFileNameWhenNotSet() {
  # unset for this particular test
  unset DATA_BACKUP_FILE_NAME
  unset BACKUP_FILE_NAME

  set_script_variables > /dev/null
  exit_code=${?}

  assertEquals 0 ${exit_code}
  assertNull "BACKUP_FILE_NAME is reserved by user and script shouldn't set." "${BACKUP_FILE_NAME}"
  assertEquals "BACKUP_FILE_NAME was not set, therefore script should look to restore latest.zip from s3." \
    "latest.zip" "${DATA_BACKUP_FILE_NAME}"
}

# Override setup to avoid framework provided verbose logs
setUp

# Execute script
. "${script_to_test}" > /dev/null

# load shunit
. ${SHUNIT_PATH}
