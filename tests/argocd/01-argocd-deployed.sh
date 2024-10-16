#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"
. "${CI_SCRIPTS_DIR}"/test/test_utils.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

checkWorkloadStatus() {
  workload=$1
  namespace="argocd"
  # get workload name, available replicas, and desired replicas
  workloads=$(kubectl get "$workload" -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

  while IFS= read -r line; do
    verify_resource_with_sleep "$workload" "$namespace" "$line"
    assertEquals 0 $?
    
  done <<< "$workloads"
}

testAllWorkloadsRunning() {
  checkWorkloadStatus "statefulset"
  checkWorkloadStatus "deployment"
}

testExpectedCRDSInstalled() {
  argocd_base_yaml="${PROJECT_DIR}/k8s-configs/cluster-tools/base/git-ops/argo/base/install.yaml"
  crd_names=($(yq eval 'select(.kind == "CustomResourceDefinition") | .metadata.name' $argocd_base_yaml | grep -v -- "---"))

  for crd in "${crd_names[@]}"; do
    kubectl get crd "$crd" > /dev/null 2>&1
    assertEquals "Expected CRD: $crd missing" 0 $?
  done
}

testArgocdAppsCreated() {
  base_app="${CLUSTER_NAME}-${REGION}-${ENV_TYPE}"
  app_list=($(find "${PROJECT_DIR}" -type d -name "p1as-*" -exec basename {} \;))

  # currently all apps have the same prefix, adding them in
  app_list=("${app_list[@]/#/$base_app-}")
  app_list+=("${base_app}")

  for app in "${app_list[@]}"; do
    kubectl get app -n argocd "${app}" > /dev/null 2>&1
    assertEquals "Expected app: ${app} missing" 0 $?
  done

}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}