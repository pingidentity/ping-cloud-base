#!/bin/bash

# To test all kustomization.yaml files locally, run this script as follows from within this directory:
#     ./compile.sh compile_env_vars
#
# NOTES:
# - Set K8S_GIT_URL to a mirror of ping-cloud-base that has the manifest files to be tested in compile_env_vars.
# - Run the script from the branch under test. This will ensure that the K8S_GIT_BRANCH variable is set correctly.

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh "${1}"

SCRIPTS=$(find ${SCRIPT_HOME} -type f -name '*-kustomizations.sh')
STATUS=0

for SCRIPT in ${SCRIPTS}; do
  log "Running script ${SCRIPT}"
  ${SCRIPT} "${1}"

  RESULT=${?}
  log "Result of script ${SCRIPT}: ${RESULT}"

  test ${STATUS} -eq 0 && STATUS=${RESULT}
done

exit ${STATUS}