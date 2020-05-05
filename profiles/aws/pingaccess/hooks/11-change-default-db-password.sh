#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

parse_utility_output() {

  # parse out the OBF:JWE:<encrypted> value
  printf "${1}" | awk '/OBF/' | awk '{print $0}'
}

set -e
"${VERBOSE}" && set -x

exit 0

# Using urandom, translate the bytes into alphanumeric chars.  Wrap the chars to fit 32 chars.
random_password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

run_properties_file=${SERVER_ROOT_DIR}/conf/run.properties

echo "Changing the PingAccess H2 database file password..."

# Use the dbfilepasswd utility to change the H2 password
dbfilepasswd_output=$(sh "${SERVER_ROOT_DIR}/bin/dbfilepasswd.sh" '2Access' "${random_password}")
if [ $? -ne 0 ]; then
  echo "There was a problem changing the PingAccess H2 default database password with dbfilepasswd: " ${dbfilepasswd_output}
  exit 1
fi

file_pw_jwe=$(parse_utility_output "${dbfilepasswd_output}")

# Replace the current obfuscated file password in run.properties
sed -ir "s/^pa.jdbc.filepassword=.*/pa.jdbc.filepassword=${file_pw_jwe}/" "${run_properties_file}"

echo "Successfully changed the PingAccess H2 database file password from the default and updated the pa.jdbc.filepassword property in run.properties."


echo "Changing the PingAccess H2 user password..."

# Use the dbuserpasswd utility to change the H2 user password
dbuserpasswd_output=$(sh "${SERVER_ROOT_DIR}/bin/dbuserpasswd.sh" "${random_password}" '2Access' "${random_password}")
if [ $? -ne 0 ]; then
  echo "There was a problem changing the PingAccess H2 default database password with dbuserpasswd: " ${dbuserpasswd_output}
  exit 1
fi

user_pw_jwe=$(parse_utility_output "${dbuserpasswd_output}")

# Replace the current obfuscated user password in run.properties
sed -ir "s/^pa.jdbc.password=.*/pa.jdbc.password=${user_pw_jwe}/" "${run_properties_file}"

echo "Successfully changed the PingAccess H2 user password from the default and updated the pa.jdbc.password property in run.properties."
exit 0
