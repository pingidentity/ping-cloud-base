#!/bin/bash

. "${PROJECT_DIR}"/ci-scripts/common.sh "${1}"

if skipTest "${0}"; then
    log "Skipping test ${0}"
    exit 0
fi

function parse_password() {
  printf "${1}" | awk "/${2}/" | awk '{print $1}' | cut -d '=' -f2-
}

testChangeDefaultPassword() {

  # This is the default file and user password string for H2 --> "2Access"
  readonly pa_h2_default_obf_pw='OBF:AES:23AeD/QrI8yVQKkhNi7kYg==:6fc098ed542fa3e40515062eb5e5117e4659ba8a'

  readonly run_properties=$(kubectl exec pingaccess-admin-0 \
                            -n "${NAMESPACE}" -c pingaccess-admin \
                            -- cat out/instance/conf/run.properties)

  dbfilepassword=$(parse_password "${run_properties}" 'pa.jdbc.filepassword')

  if [ -z "${dbfilepassword}" ]; then
    log "dbfilepassword should NOT be empty!"
    exit 1
  fi

  if [ "${pa_h2_default_obf_pw}" == "${dbfilepassword}" ];then
      log "The pa.jdbc.filepassword should NOT be the default!"
      exit 1
    else
      log "The pa.jdbc.filepassword was correctly changed from the default."
  fi


  dbuserpassword=$(parse_password "${run_properties}" 'pa.jdbc.password')

  if [ -z "${dbuserpassword}" ]; then
    log "dbuserpassword should NOT be empty!"
    exit 1
  fi

  if [ "${pa_h2_default_obf_pw}" == "${dbuserpassword}" ];then
      log "The pa.jdbc.password should NOT be the default!"
      exit 1
    else
      log "The pa.jdbc.password was correctly changed from the default."
  fi

  # If we get to this point
  # signal to shunit that the
  # test was a success
  assertEquals 0 0
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
