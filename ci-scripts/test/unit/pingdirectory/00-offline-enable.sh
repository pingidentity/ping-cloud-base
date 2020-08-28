#!/bin/bash

# Source the script we're testing
script_to_test="${PROJECT_DIR}"/profiles/aws/pingdirectory/hooks/utils.offline-enable.sh

# Mock functions that are used in utils.offline-enable.sh.
is_multi_cluster() {
  # This is treated as a boolean within util.lib.sh we are defaulting this to true.
  # This is needed to test that the primary and secondary region key name is provided descriptor.json.
  test 0 -eq 0
}
beluga_log() {
  return 0
}

setUp() {
  # Mock empty files for script to avoid no directory exist error.
  export HOOKS_DIR=$(mktemp -d)
  touch "${HOOKS_DIR}"/pingcommon.lib.sh
  touch "${HOOKS_DIR}"/utils.lib.sh

  export regions_file=$(mktemp)

  SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
  templates_dir_path="${SCRIPT_HOME}"/templates/offline-enable
}

oneTimeTearDown() {
  [[ "${_shunit_name_}" = 'EXIT' ]] && return 0
  rm ${regions_file}
}

testParamsOfflineEnableScript() {
  # Set config_json variable, which is used by utils.offline-enable.sh
  export config_json="${templates_dir_path}"/01-valid-offline-enable-config.json
  verifyParams > /dev/null
  actual_exit_code=$?
  assertEquals "All required params injected into offline-enable expected to pass" 0 ${actual_exit_code}

  export config_json="${templates_dir_path}"/03-missing-params-local-region-offline-enable-config.json
  verifyParams > /dev/null
  actual_exit_code=$?
  assertEquals "The missing required param, local_region, is expected to fail when injected into script" 1 ${actual_exit_code}
}

testDescriptorJsonSyntax() {
  # Set descriptor_json variable, which is used by utils.offline-enable.sh

  export descriptor_json="${templates_dir_path}"/00-valid-descriptor.json
  validateDescriptorJsonSyntax
  actual_exit_code=$?
  assertEquals "Valid descriptor JSON expected to pass" 0 ${actual_exit_code}

  export descriptor_json="${templates_dir_path}"/02-invalid-syntax-descriptor.json
  validateDescriptorJsonSyntax
  actual_exit_code=$?
  assertEquals "Un-parsable descriptor JSON expected to fail" 1 ${actual_exit_code}

  export descriptor_json="${templates_dir_path}"/10-empty-file.json
  validateDescriptorJsonSyntax
  actual_exit_code=$?
  assertEquals "Empty descriptor JSON expected to fail" 1 ${actual_exit_code}
}

testDescriptorJsonSchema() {
  # Set export descriptor_json variable, which is used by utils.offline-enable.sh

  export descriptor_json="${templates_dir_path}"/00-valid-descriptor.json
  verifyDescriptorJsonSchema > /dev/null
  actual_exit_code=$?
  assertEquals "Valid descriptor JSON expected to pass" 0 ${actual_exit_code}

  export descriptor_json="${templates_dir_path}"/09-spaces-within-region-name.json
  verifyDescriptorJsonSchema > /dev/null
  actual_exit_code=$?
  assertEquals "Spaces in region name in descriptor JSON expected to fail" 1 ${actual_exit_code}

  export descriptor_json="${templates_dir_path}"/04-empty-json-descriptor.json
  verifyDescriptorJsonSchema > /dev/null
  actual_exit_code=$?
  assertEquals "No regions in descriptor JSON expected to fail" 1 ${actual_exit_code}

  export descriptor_json="${templates_dir_path}"/05-duplicate-region-name-descriptor.json
  verifyDescriptorJsonSchema > /dev/null
  actual_exit_code=$?
  assertEquals "Duplicate region names in descriptor JSON expected to fail" 1 ${actual_exit_code}

  export descriptor_json="${templates_dir_path}"/06-missing-hostname-json-descriptor.json
  verifyDescriptorJsonSchema > /dev/null
  actual_exit_code=$?
  assertEquals "Missing hostname in descriptor JSON expected to fail" 1 ${actual_exit_code}

  export descriptor_json="${templates_dir_path}"/07-invalid-count-descriptor.json
  verifyDescriptorJsonSchema > /dev/null
  actual_exit_code=$?
  assertEquals "Invalid replica count in descriptor JSON expected to fail" 1 ${actual_exit_code}

  export descriptor_json="${templates_dir_path}"/08-missing-count-json-descriptor.json
  verifyDescriptorJsonSchema > /dev/null
  actual_exit_code=$?
  assertEquals "Missing replica count in descriptor JSON expected to fail" 1 ${actual_exit_code}
}

# Override setup to avoid framework provided verbose logs
setUp

# Execute script
. "${script_to_test}" > /dev/null

# load shunit
. ${SHUNIT_PATH}