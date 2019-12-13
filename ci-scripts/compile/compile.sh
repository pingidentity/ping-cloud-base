#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

SCRIPTS=$(find ${SCRIPT_HOME} -type f -name '*-kustomizations.sh')

for SCRIPT in ${SCRIPTS}; do
  log "Running script ${SCRIPT}"
  ${SCRIPT}
done