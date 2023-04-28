#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
   TMP_JVM_ARGS_FILE=$(mktemp)
   TMP_ENV_ARGS_FILE=$(mktemp)

   # get the logs and jvm arguments 
   # since all the other product pods are connecting to PD-0 during start up, 
   # more logs are getting generated and not able to fetch the required values from the log 
   # files. So using logs from PD-1
   kubectl logs pingdirectory-1 pingdirectory -n "${PING_CLOUD_NAMESPACE}" | grep ^start-server > "${TMP_ENV_ARGS_FILE}"

   # since all the other product pods are connecting to PD-0 during start up and we are getting 
   # logs from PD-1 in above
   # statement, get the jvm args from PD-1 jvm
   # since the position of the actual argument start at 5, trying to get the values starting 
   # from 5th column to the last column
   # 16 ping     11:14 /opt/java/bin/java -Xmx3g -Xms3g
   kubectl exec pingdirectory-1 -c pingdirectory -n "${PING_CLOUD_NAMESPACE}" -- /bin/bash -c ps -ef | grep java |\
                                    awk 'NR==1 {print $0}' | \
                                    awk '{for (i = 5; i <= NF; i++) {printf "%s ", $i}; printf "\n"}' > "${TMP_JVM_ARGS_FILE}"

    jvmargs=$(cat $TMP_JVM_ARGS_FILE)
}

oneTimeTearDown() {
    # Need this to suppress tearDown on script EXIT
    [[ "${_shunit_name_}" = 'EXIT' ]] && return 0
   
   if test -f $TMP_JVM_ARGS_FILE; then
       rm -rf $TMP_JVM_ARGS_FILE
   fi

   if test -f $TMP_ENV_ARGS_FILE; then
       rm -rf $TMP_ENV_ARGS_FILE
   fi
}

get_arg(){

    local java_arg_property=${1}
    # since the position of the actual argument start at 6, trying to get the values starting from 6th column to the last column
    # start-server: 2023-03-27 16:44:21 INFO SCRIPT_NAME_ARG: -Dcom.unboundid.directory.server.scriptName=start-server
    local env_arg=$(cat "${TMP_ENV_ARGS_FILE}" | grep ${java_arg_property} | awk '{for (i = 6; i <= NF; i++) {printf "%s ", $i}; printf "\n"}')
    echo $env_arg
}

test_private_unboundid_java_args(){
    prv_status=1
    private_unboundid_java_args=$(get_arg "PRIVATE_UNBOUNDID_JAVA_ARGS")
    
    if [[ ${jvmargs} == *${private_unboundid_java_args}* ]]; then
        prv_status=0
        log "PRIVATE_UNBOUNDID_JAVA_ARGS is set"
    else 
        log "PRIVATE_UNBOUNDID_JAVA_ARGS is not properly configured, current value is : $private_unboundid_java_args"
    fi
    
    assertEquals "PRIVATE_UNBOUNDID_JAVA_ARGS is not properly configured" 0 "${prv_status}"
}

test_beluga_java_args(){
    bel_status=1
    beluga_java_args=$(get_arg "BELUGA_JAVA_ARGS")
    
    if [[ ${jvmargs} == *${beluga_java_args}* ]]; then
        bel_status=0
        log "BELUGA_JAVA_ARGS is set"
    else 
        log "BELUGA_JAVA_ARGS is not properly configured, current value is : $beluga_java_args"

    fi
    
    assertEquals "BELUGA_JAVA_ARGS is not properly configured" 0 "${bel_status}"
}

test_loggc_arg(){
    loggc_status=1
    loggc_arg=$(get_arg "LOGGC_ARG")
    
    if [[ ${loggc_arg} == *"\"\${PRIVATE_UNBOUNDID_LOGGC_ARG}\""* ]]; then
        loggc_status=0
        log "LOGGC_ARG is set"
    else 
        log "LOGGC_ARG is not properly configured, current value is : $loggc_arg"
    fi
    
    assertEquals "LOGGC_ARG is not properly configured" 0 "${loggc_status}"
}

test_script_name_arg(){
    sn_status=1
    script_name_arg=$(get_arg "SCRIPT_NAME_ARG")
    
    if [[ ${jvmargs} == *${script_name_arg}* ]]; then
        sn_status=0
        log "SCRIPT_NAME_ARG is set"
    else 
        log "SCRIPT_NAME_ARG is not properly configured, current value is : $script_name_arg"
    fi
    
    assertEquals "SCRIPT_NAME_ARG is not properly configured" 0 "${sn_status}"
}

test_java_agent_opts(){
    ja_status=1
    java_agent_opts=$(get_arg "JAVA_AGENT_OPTS")
    
    if [[ ${jvmargs} == *${java_agent_opts}* ]]; then
        ja_status=0
        log "JAVA_AGENT_OPTS is set"
    else 
        log "JAVA_AGENT_OPTS is not properly configured, current value is : $java_agent_opts"
    fi
    
    assertEquals "JAVA_AGENT_OPTS is not properly configured" 0 "${ja_status}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}