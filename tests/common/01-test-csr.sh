#!/bin/bash
# shellcheck disable=SC2164,SC1090,SC1091,SC2086,SC2155

# To run this test locally, follow the instructions in tests/README.md

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# Get the substring for the repo name after `/` since CLUSTER_STATE_REPO_URL contains more than just the repo name
CSR_NAME=${CLUSTER_STATE_REPO_URL##*\/}

setUp() {
    # Remove CSR if it exists, moved from tearDown as pwd errors were occurring
    rm -rf /tmp/${CSR_NAME}

    # NOTE: copy of logic from k8s-deploy-tools/ci-scripts/k8s-deploy/deploy.sh
    local branch_name=""
    if [[ ${ENV_TYPE} == "prod" ]]; then
        branch_name="master"
    else
        branch_name="${ENV_TYPE}"
    fi

    ## Special env setup for seal.sh to work properly in these tests ##
    # Set LOCAL for to pull the PCB_PATH properly
    export LOCAL="true"
    # Use PROJECT_DIR if provided manually, otherwise use CI_PROJECT_DIR set by Gitlab,
    # since PCB will already be checked out
    export PCB_PATH=${PROJECT_DIR:-$CI_PROJECT_DIR}
    ###################################################################

    cd /tmp || exit 1
    git clone -b "${branch_name}" codecommit://${CSR_NAME}
    cd /tmp/${CSR_NAME}/k8s-configs
    ./seal.sh
}

# Test that the counts match of the secrets sealed vs the secrets which weren't sealed previously
test_seal_secret_count_match() {
    num_secrets=$(grep -c "kind: Secret" /tmp/ping-secrets.yaml)
    num_sealed_secrets=$(grep -c "kind: SealedSecret" /tmp/sealed-secrets.yaml)
    assertEquals "Checking secret and sealed secret counts match" "${num_secrets}" "${num_sealed_secrets}"
}

# Test that there are no unexpected secrets in the uber yaml output
test_no_secret_in_uber_yaml() {
    # Copy the sealed secrets into the cluster-state-repo directory
    cp /tmp/ping-secrets.yaml base/secrets.yaml
    cp /tmp/sealed-secrets.yaml base/sealed-secrets.yaml

    # Re-run uber yaml output as seal.sh does not save its output
    local uber_yaml_output="/tmp/test-uber-output.yaml"

    echo "Generating uber yaml..."
    ./git-ops-command.sh ${REGION} > ${uber_yaml_output}

    # Find all kind: Secrets at the top level, ignoring karpenter-cert as it's managed by karpenter
    yq 'select(.kind == "Secret") | select(.metadata.name != "karpenter-cert")' ${uber_yaml_output} -e
    assertEquals "yq exit code should be 1 as no matches are found" 1 $?
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}