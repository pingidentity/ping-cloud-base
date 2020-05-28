#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

# Generate the code first
export TENANT_NAME="${EKS_CLUSTER_NAME}"
export K8S_GIT_URL=${CI_REPOSITORY_URL}
export K8S_GIT_BRANCH=${CI_COMMIT_REF_NAME}
export TARGET_DIR=/tmp/sandbox

STATUS=0

for SIZE in small medium large; do
  log "Building kustomizations for ${SIZE} environment"

  export SIZE
  ${PROJECT_DIR}/code-gen/generate-cluster-state.sh

  # Verify that all kustomizations are able to be built
  build_kustomizations_in_dir "${TARGET_DIR}"
  BUILD_STATUS=${?}
  log "Build result for ${SIZE} kustomizations: ${BUILD_RESULT}"

  test ${STATUS} -eq 0 && STATUS=${BUILD_RESULT}
done

exit ${STATUS}