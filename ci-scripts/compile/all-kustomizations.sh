#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

STATUS=0

# All kustomizations in k8s-configs directory
PING_CLOUD_BASE_DIR="${CI_PROJECT_DIR}/k8s-configs"

build_kustomizations_in_dir "${PING_CLOUD_BASE_DIR}"
STATUS=${?}

# All kustomizations in base test directory
PING_CLOUD_TEST_DIR="${CI_PROJECT_DIR}/test"

build_kustomizations_in_dir "${PING_CLOUD_TEST_DIR}"
BUILD_RESULT=${?}
test ${STATUS} -eq 0 && STATUS=${BUILD_RESULT}

# Root kustomization.yaml file
log "Building root ${CI_PROJECT_DIR} kustomization.yaml"

kustomize build "${CI_PROJECT_DIR}" 1> /dev/null
BUILD_RESULT=${?}
test ${STATUS} -eq 0 && STATUS=${BUILD_RESULT}

log "Build result for root ${CI_PROJECT_DIR} kustomization.yaml: ${BUILD_RESULT}"

exit ${STATUS}