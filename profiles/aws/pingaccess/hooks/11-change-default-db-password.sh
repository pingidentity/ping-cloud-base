#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

parse_utility_output() {

  # parse out the OBF:JWE:<encrypted> value
  printf "${1}" | awk '/OBF/' | awk '{print $0}'
}

"${VERBOSE}" && set -x

readonly run_properties_file=${SERVER_ROOT_DIR}/conf/run.properties

# This is the default file and user password string for H2
readonly pa_h2_default_obf_pw='OBF:AES:23AeD/QrI8yVQKkhNi7kYg==:6fc098ed542fa3e40515062eb5e5117e4659ba8a'


# cut -d '=' -f2-  gathers a range of fields (2nd field to the last field -f<from>-<to>) after the first =
# We're parsing a line like this: pa.jdbc.filepassword=<value with multiple = signs)
existing_filepasswd=$(cat "${run_properties_file}" | awk '/pa.jdbc.filepassword/' | awk '{print $1}' | cut -d '=' -f2- )
if [ $? -ne 0 ]; then
  beluga_log "Cannot read the pa.jdbc.filepassword value from conf/run.properties"
  exit 1
fi

if [ "${pa_h2_default_obf_pw}" != "${existing_filepasswd}" ]; then
  beluga_log "PingAccess is NOT using the default H2 password.  No changes are necessary."
  exit 0
fi


# Using urandom, translate the bytes into alphanumeric chars.  Wrap the chars to fit 32 chars.
random_password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

beluga_log "Changing the PingAccess H2 database file password..."

# Use the dbfilepasswd utility to change the H2 password
dbfilepasswd_output=$(sh "${SERVER_ROOT_DIR}/bin/dbfilepasswd.sh" '2Access' "${random_password}")

dbfilepasswd_output_code=$?
if [ $? -ne 0 ]; then
  beluga_log "There was a problem changing the PingAccess H2 default database password with dbfilepasswd: ${dbfilepasswd_output_code}"
  exit 1
fi

file_pw_jwe=$(parse_utility_output "${dbfilepasswd_output}")

# Replace the current obfuscated file password in run.properties
sed -i "s/^pa.jdbc.filepassword=.*/pa.jdbc.filepassword=${file_pw_jwe}/" "${run_properties_file}"

beluga_log "Successfully changed the PingAccess H2 database file password from the default and updated the pa.jdbc.filepassword property in run.properties."
echo

beluga_log "Changing the PingAccess H2 user password..."

# Use the dbuserpasswd utility to change the H2 user password
dbuserpasswd_output=$(sh "${SERVER_ROOT_DIR}/bin/dbuserpasswd.sh" "${random_password}" '2Access' "${random_password}")

dbuserpasswd_output_code=$?
if [ $? -ne 0 ]; then
  beluga_log "There was a problem changing the PingAccess H2 default database password with dbuserpasswd: ${dbuserpasswd_output_code}"
  exit 1
fi

user_pw_jwe=$(parse_utility_output "${dbuserpasswd_output}")

# Replace the current obfuscated user password in run.properties
sed -i "s/^pa.jdbc.password=.*/pa.jdbc.password=${user_pw_jwe}/" "${run_properties_file}"

beluga_log "Successfully changed the PingAccess H2 user password from the default and updated the pa.jdbc.password property in run.properties."

# PDO-989 - Save the new passwords to a backup file to be restored
# if the pod gets deleted.
h2_props_backup="${SERVER_ROOT_DIR}/conf/h2_password_properties.backup"
beluga_log "Backing up the H2 database password properties to ${h2_props_backup}..."

# Write these 2 properties on separate lines in the backup file
printf "pa.jdbc.filepassword=${file_pw_jwe}" > "${h2_props_backup}"
printf '\n' >> "${h2_props_backup}"
printf "pa.jdbc.password=${user_pw_jwe}" >> "${h2_props_backup}"
printf '\n' >> "${h2_props_backup}"

beluga_log "Successfully backed up the password properties to ${h2_props_backup}:"
echo
cat "${h2_props_backup}"

exit 0
