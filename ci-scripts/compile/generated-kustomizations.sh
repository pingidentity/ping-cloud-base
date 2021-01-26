#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh "${1}"

# Generate the code first
export TENANT_NAME="${TENANT_NAME:-${EKS_CLUSTER_NAME}}"
export K8S_GIT_URL=${K8S_GIT_URL:-${CI_REPOSITORY_URL}}
export K8S_GIT_BRANCH=${K8S_GIT_BRANCH:-${CI_COMMIT_REF_NAME}}
export TARGET_DIR=/tmp/sandbox

STATUS=0

for SIZE in x-small small medium large; do
  log "Building cluster state code for size '${SIZE}'"

  SIZE="${SIZE}" "${PROJECT_DIR}/code-gen/generate-cluster-state.sh"

  # Verify that all kustomizations are able to be built
  build_generated_code "${TARGET_DIR}"
  BUILD_STATUS=${?}
  log "Build result for cluster state code for size '${SIZE}': ${BUILD_STATUS}"

  test ${STATUS} -eq 0 && STATUS=${BUILD_STATUS}
done

exit ${STATUS}
