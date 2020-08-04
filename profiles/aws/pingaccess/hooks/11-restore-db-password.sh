#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

print_differences() {
  echo "Changed ${1} from: "
  echo "${2}"
  echo "to: "
  echo "${3}"
}

"${VERBOSE}" && set -x

readonly run_properties_file=${SERVER_ROOT_DIR}/conf/run.properties
readonly h2_props_backup="${SERVER_ROOT_DIR}/conf/h2_password_properties.backup"

# Look for the h2_props_backup file
if [ -f "${h2_props_backup}" ]; then
  beluga_log "Found the H2 database password properties file: ${h2_props_backup} with the properties:"
  echo
  cat "${h2_props_backup}"
else
  beluga_log "Could not find the H2 database password properties file: ${h2_props_backup}"
  "${HOOKS_DIR}"/11-change-default-db-password.sh
  exit $?
fi

echo
beluga_log "Restoring the password properties from ${h2_props_backup} to ${run_properties_file}..."

# Save existing to print the difference later
existing_filepassword=$(cat "${run_properties_file}" | awk '/pa.jdbc.filepassword/' | awk '{print $0}')
existing_dbuserpassword=$(cat "${run_properties_file}" | awk '/pa.jdbc.password/' | awk '{print $0}')

# Get the lines from the H2 db password properties backup file
dbfilepassword_line=$(cat "${h2_props_backup}" | awk '/pa.jdbc.filepassword/' | awk '{print $0}')
dbuserpassword_line=$(cat "${h2_props_backup}" | awk '/pa.jdbc.password/' | awk '{print $0}')

# Replace the current obfuscated file password in run.properties
sed -i "s/^pa.jdbc.filepassword=.*/${dbfilepassword_line}/" "${run_properties_file}"

# Replace the current obfuscated user password in run.properties
sed -i "s/^pa.jdbc.password=.*/${dbuserpassword_line}/" "${run_properties_file}"

echo
beluga_log $(print_differences 'pa.jdbc.filepassword' "${existing_filepassword}" "${dbfilepassword_line}")
echo
beluga_log $(print_differences 'pa.jdbc.password' "${existing_dbuserpassword}" "${dbuserpassword_line}")

exit 0
