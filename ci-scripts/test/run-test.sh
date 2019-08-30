#!/bin/bash
set -e

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

TEST_DIR=${SCRIPT_HOME}/$1

for script in $(find ${TEST_DIR} -name \*.sh); do
  log "Running script ${script}"
  ${script}
done