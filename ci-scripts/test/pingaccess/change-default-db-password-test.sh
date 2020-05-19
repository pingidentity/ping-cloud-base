#!/bin/bash

function parse_password() {
  printf "${1}" | awk "/${2}/" | awk '{print $1}' | cut -d '=' -f2-
}

echo ">>>> Starting ${0} test..."

# This is the default file and user password string for H2 --> "2Access"
readonly pa_h2_default_obf_pw='OBF:AES:23AeD/QrI8yVQKkhNi7kYg==:6fc098ed542fa3e40515062eb5e5117e4659ba8a'

readonly run_properties=$(kubectl exec pingaccess-admin-0 \
                          -n "${NAMESPACE}" -c pingaccess-admin \
                          -- cat out/instance/conf/run.properties)

dbfilepassword=$(parse_password "${run_properties}" 'pa.jdbc.filepassword')
#echo
#echo "New pa.jdbc.filepassword is: ${dbfilepassword}"
#echo
if [ -z "${dbfilepassword}" ]; then
  echo "dbfilepassword should NOT be empty!"
  exit 1
fi

if [ "${pa_h2_default_obf_pw}" == "${dbfilepassword}" ];then
    echo "The pa.jdbc.filepassword should NOT be the default!"
    exit 1
  else
    echo "The pa.jdbc.filepassword was correctly changed from the default."
fi


dbuserpassword=$(parse_password "${run_properties}" 'pa.jdbc.password')
#echo
#echo "New pa.jdbc.password is: ${dbuserpassword}"
#echo
if [ -z "${dbuserpassword}" ]; then
  echo "dbuserpassword should NOT be empty!"
  exit 1
fi

if [ "${pa_h2_default_obf_pw}" == "${dbuserpassword}" ];then
    echo "The pa.jdbc.password should NOT be the default!"
    exit 1
  else
    echo "The pa.jdbc.password was correctly changed from the default."
fi

echo ">>>> ${0} finished..."
exit 0
