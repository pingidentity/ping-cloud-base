#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

# Configure aws and kubectl, unless skipped
configure_aws
configure_kube

TEST_DIRS=${@}
[[ -z ${TEST_DIRS} ]] &&
  TEST_DIRS=$(find ${SCRIPT_HOME} -type d -mindepth 1 -exec basename '{}' \;)

for TEST_DIR in ${TEST_DIRS}; do
  for SCRIPT in $(find ${SCRIPT_HOME}/${TEST_DIR} -name \*.sh | sort); do
    log "Running script ${SCRIPT}"
    ${SCRIPT}
  done
done