#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh "${1}"

STATUS=0

# All kustomizations in k8s-configs directory
PING_CLOUD_BASE_DIR="${PROJECT_DIR}/k8s-configs"

build_kustomizations_in_dir "${PING_CLOUD_BASE_DIR}"
STATUS=${?}

# All kustomizations in dev cluster state directory
PING_CLOUD_TEST_DIR="${PROJECT_DIR}/dev-cluster-state"

build_kustomizations_in_dir "${PING_CLOUD_TEST_DIR}"
BUILD_RESULT=${?}
test ${STATUS} -eq 0 && STATUS=${BUILD_RESULT}

# Root kustomization.yaml file
log "Building root ${PROJECT_DIR} kustomization.yaml"

kustomize build --load_restrictor none "${PROJECT_DIR}" 1> /dev/null
BUILD_RESULT=${?}
test ${STATUS} -eq 0 && STATUS=${BUILD_RESULT}

log "Build result for root ${PROJECT_DIR} kustomization.yaml: ${BUILD_RESULT}"

exit ${STATUS}