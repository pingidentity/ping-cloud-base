#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

test_check_bash_version(){
    #invoke the check_bash_version() by passing a name space we want to check
    check_bash_version $PING_CLOUD_NAMESPACE
    test_status=$?
    if [[ $test_status -eq 0 ]]; then
        log "check_bash_version test is successful"
        success=0
    else 
        log "check_bash_version test exited with code $test_status"
        success=1
    fi
    assertEquals 0 ${success}
}

########################################################################################################################
# Method to check if the containers inside the pods of a given namespace is configured with bash.
# Arguments
#   ${1} -> NAMESPACE
########################################################################################################################
check_bash_version(){
  local ns_to_check=${1}
  log "checking namespace : ${ns_to_check}"
  kubectl get pods -n "${ns_to_check}" | awk 'NR!=1 {print $1}' | while read current_pod_info; do
        pod_name=$(echo $current_pod_info | awk '{print $1}')
        # Get all the containers within the pod
        log "checking pod : ${pod_name}"
        for container_name in $(kubectl get pod $pod_name -n "${ns_to_check}" -o jsonpath="{.spec['containers'][*].name}"); do
            #exec into the pod and check for bash in the list of shells installed in the containers
            bash_path=$(kubectl exec $pod_name -c $container_name -n "${ns_to_check}" -- cat /etc/shells 2>&1 | grep '/bin/bash' 2>&1 )
            shell_status=$?
            if [[ shell_status -eq 0 ]]; then
                bash_version=$(kubectl exec $pod_name -c $container_name -n "${ns_to_check}" -- bash --version 2>&1 | awk 'NR==1 {print $4}')
                log "Container : ^^^^ $container_name ^^^^ is configured with bash version : ^^^^ $bash_version ^^^^ located at path : $bash_path"
            else
                log "Container : ^^^^ $container_name ^^^^ does not have bash configured"
                exit 1
            fi
        done
  done
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}