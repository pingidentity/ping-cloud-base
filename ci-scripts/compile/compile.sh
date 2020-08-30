#!/bin/bash

# To test all kustomization.yaml files locally, run this script as follows from within this directory:
#     ./compile.sh compile_env_vars
#
# NOTE: Change CONFIG_REPO_BRANCH to the name of the branch under test in compile_env_vars

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh "${1}"

SCRIPTS=$(find ${SCRIPT_HOME} -type f -name '*-kustomizations.sh')
STATUS=0

for SCRIPT in ${SCRIPTS}; do
  log "Running script ${SCRIPT}"
  ${SCRIPT} "${1}"
  RESULT=${?}
  test ${STATUS} -eq 0 && STATUS=${RESULT}
done

exit ${STATUS}