#!/bin/bash

TEST_DIR="${1}"
ENV_VARS_FILE="${2}"

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. "${SCRIPT_HOME}"/../common.sh "${ENV_VARS_FILE}"

# Configure aws and kubectl, unless skipped
configure_aws
configure_kube

for SCRIPT in $(find "${SCRIPT_HOME}/${TEST_DIR}" -name \*.sh | sort); do
  log "Running test ${SCRIPT}"
  ${SCRIPT} "${ENV_VARS_FILE}"
  log "Test result: $?"
  echo
done