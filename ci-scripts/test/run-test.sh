#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

# Configure aws and kubectl, if not running in debug mode
if test "${1}" != 'debug'; then
  log "Configuring aws CLI"
  configure_aws

  log "Configuring kubectl"
  configure_kube
fi

TEST_DIRS=${@}
[[ -z ${TEST_DIRS} ]] &&
  TEST_DIRS=$(find ${SCRIPT_HOME} -type d -mindepth 1 -exec basename '{}' \;)

for dir in ${TEST_DIRS}; do
  for script in $(find ${SCRIPT_HOME}/${dir} -name \*.sh | sort); do
    log "Running script ${script}"
    ${script}
  done
done