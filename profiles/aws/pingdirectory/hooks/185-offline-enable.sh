#!/usr/bin/env sh

# Copyright 2020 Ping Identity Corporation
# All Rights Reserved.

# The definitive version of this script is in the "pingdirectory" git repo in
# this directory:
#   tests/unit-tests/resource/offline-enable.sh
# Please make any changes there run its unit test:
#  ./build.sh -Dtest.classes=OfflineEnableTest test

# This can be used to enable replication offline without using
# "dsreplication enable". It works by updating entries in config/config.ldif
# directly bypassing the usual mechanism to make such changes.
#
# The configuration (config.ldif) is updated via "ldifmodify". If there is a
# server instance for the local instance it will be used as a template to build
# the server instances for the remote servers.
#
# In the case where a server has been setup but not started various DNs are
# added to config.ldif. Here are examples of what might be added grouped by
# theme:
#
# Server instances with a zero based ordinal number:
#   cn=Server Instances,cn=Topology,cn=config
#   cn=example:0,cn=Server Instances,cn=Topology,cn=config
#   cn=example:1,cn=Server Instances,cn=Topology,cn=config
#
# A replication server and one DN per replicated base DN:
#   cn=replication server,cn=Multimaster Synchronization,cn=Synchronization Providers,cn=config
#   cn=dc_example_dc_com,cn=domains,cn=Multimaster Synchronization,cn=Synchronization Providers,cn=config
#   cn=dc_other_dc_com,cn=domains,cn=Multimaster Synchronization,cn=Synchronization Providers,cn=config
#
# Administrative user "admin":
#   cn=Topology Admin Users,cn=topology,cn=config
#   cn=admin,cn=Topology Admin Users,cn=topology,cn=config
#
# Server group "replication-servers":
# members of the "replication-servers" group:
#   cn=Server Groups,cn=topology,cn=config
#   cn=replication-servers,cn=Server Groups,cn=topology,cn=config

# Semi-strict mode (no pipefail).
set -eu

# Globals

bname="${0##*/}"
tmp_dir=$(mktemp -td "${bname}.XXXXXXXXXX")
do_cleanup=t

# Maximum values applied to command line arguments.
max_ordinal=99
max_id_base=32700
max_id_inc=100
max_port=65000
max_port_inc=100
max_count=100

# Set to true in order to use the existing local server instance as template to
# build the remote server instances.
existing_local_server_as_template="t"

# The configuration parameters passed to this script via a JSON configuration file.
params="descriptor_json inst_root local_region local_ordinal inst_base inst_inc repl_id_base repl_id_rinc \
  repl_id_inc ldap_port_base ldap_port_inc ldaps_port_base ldaps_port_inc repl_port_base repl_port_inc ads_truststore \
  admin_user admin_pass_file"

# Functions

# Cleanup temporary files.
cleanup()
{
  if [ ! -z ${do_cleanup} ]; then
    log "Cleaning up temporary directory \"${tmp_dir}\"."
    # Slightly safer than "rm -rf"
    rm -f "${tmp_dir}"/*
    rmdir "${tmp_dir}"
  else
    log "Keeping temporary directory \"${tmp_dir}\"."
  fi
}

# Log to stderr and exit.
fatal()
{
  local msg="${1}"

  warn "$msg"
  exit 1
}

# Log to stdout.
log()
{
  local msg="${1}"

  if [ ! -z ${opt_v} ]; then
    echo "$(date): ${msg}"
  fi
}

# Log to stderr.
warn()
{
  local msg="${1}"

  echo "$(date): ${msg}" 1>&2
}

# Check that variable "var" is a valid integer in a specified range.
check_int()
{
  local var="${1}"
  local min="${2}"
  local max="${3}"

  local val=$(eval echo \"\${${var}}\")
  if ! echo "${val}" | grep -Eq "^-?[0-9]+$"; then
    fatal "Variable \"${var}\" with value \"${val}\" is not an integer."
  fi

  if [ \( "${val}" -lt "${min}" \) -o \( "${val}" -gt "${max}" \) ]; then
    fatal "Variable \"${var}\" with value \"${val}\" is not in range [${min}, ${max}]."
  fi
}

# Check that the specified JSON file is readable and is type object.
check_json_object()
{
  local json_file="${1}"

  if [ ! -r "${json_file}" ]; then
    fatal "JSON file \"${json_file}\" can not be read."
  fi

  json_type=$(jq -r type "${json_file}")
  if [ "${json_type}" != object ]; then
    fatal "JSON file \"${json_file}\" must be type \"object\", but is type \"${json_type}\"."
  fi
}

# Print out a callstack for errors.
error()
{
  warn "Unhandled error in ${bname}:"

  # Bash is not required for this script, but if it's available, due to "sh"
  # being a symlink to "bash", then the following non-essential lines will show
  # the callstack for fatal errors. It's helpful for debugging.
  if [ ! -z "${BASH_VERSION:-}" ]; then
    # It's possible to get a callstack for bash.
    indent="  "
    i=${#BASH_LINENO[@]}
    i=$((i - 1))
    while [ ${i} -gt 0 ]; do
      echo "${indent}${BASH_SOURCE[${i}]}.${FUNCNAME[${i}]}():${BASH_LINENO[${i}-1]}" 1>&2
      indent="  ${indent}"
      i=$((i - 1))
    done
  else
    echo "${indent}Callstack not available for this shell." 1>&2
  fi

  # Leave temporary files around to examine if there is an error.
  do_cleanup=""
}

# Escape base DNs so that they can appear in LDIF.
escape_dn()
{
  local dn="${1}"

  echo "${dn}" | tr ',=' "__"
}

# Escape strings so that they can appear in grep.
escape_regex()
{
  local str="${1}"

  echo "${str}" | sed 's/\([.^$]\)/\\\1/g'
}

### Main Entry ###

# Parse options.
if [ \( $# -ge 1 \) -a \( "${1:-}" = "-v" \) ]; then
  opt_v=t
  shift
else
  opt_v=""
fi

# Check the number of remaining non-option arguments. +1 because at least one
# domain is required.
if [ $# -lt 2 ]; then
  fatal "Usage: ${bname} [-v] config_json base_dn_1 [base_dn_2 ...]
  config_json     A JSON configuration file.
  base_dn_N       One or more base DNs"
fi

# Fixed parameters.
config_json="${1}"
check_json_object "${config_json}"

# After the following shift the base DNs will be in position parameters $1, $2 ...
shift

for param in ${params}; do
  value=$(jq -r ".${param}" "${config_json}")
  if [ -z "${value}" ] || [ ${value} == null ]; then
    fatal "Parameter \"${param}\" is missing from configuration file \"${config_json}\"."
  fi
  eval $param=\"\${value}\"
done

log "Begin for \"${inst_root}\"."

# Paths relative to the install directory.
conf="${inst_root}/config/config.ldif"
dsconfig="${inst_root}/bin/dsconfig"
ldifmodify="${inst_root}/bin/ldifmodify"
mcerts="${inst_root}/bin/manage-certificates"

# Validate arguments.

if [ ! -f "${conf}" ]; then
  fatal "Directory \"${inst_root}\" is not a valid install."
fi

check_int "local_ordinal"   0 "${max_ordinal}"
check_int "inst_base"       0 "${max_port}"
check_int "inst_inc"        0 "${max_port_inc}"
check_int "repl_id_base"    0 "${max_id_base}"
check_int "repl_id_rinc"    1 "${max_id_base}"
check_int "repl_id_inc"     1 "${max_id_inc}"
check_int "ldap_port_base"  0 "${max_port}"
check_int "ldap_port_inc"   0 "${max_port_inc}"
check_int "ldaps_port_base" 0 "${max_port}"
check_int "ldaps_port_inc"  0 "${max_port_inc}"
check_int "repl_port_base"  0 "${max_port}"
check_int "repl_port_inc"   0 "${max_port_inc}"

check_json_object "${descriptor_json}"

# Determine the local hostname and count.
local_hostname_template=$(jq -r ".[\"${local_region}\"].hostname" "${descriptor_json}")
# Hostnames with "${ordinal}", if any, are replaced with the correct ordinal.
local_hostname=$(export ordinal=${local_ordinal}; echo "${local_hostname_template}" | envsubst)
local_count=$(jq -r ".[\"${local_region}\"].replicas" "${descriptor_json}")

if [ ${local_ordinal} -ge ${local_count} ]; then
  fatal "Local ordinal \"${local_ordinal}\" must be less than count \
\"${count}\"."
fi

# Special value "none" to not change ads_truststore.
if [ "${ads_truststore}" = "none" ]; then
  ads_truststore=""
fi

if [ ! -f "${ads_truststore}" ]; then
  fatal "ads_truststore \"${ads_truststore}\" does not exist."
fi

if [ ! -f "${admin_pass_file}" ]; then
  fatal "admin_pass_file \"${admin_pass_file}\" does not exist."
fi

# Traps:
#      function  event
trap   cleanup   EXIT
if [ ! -z "${BASH_VERSION:-}" ]; then
  # Error handling for bash only.
  trap error     ERR
  set -E # Error handler for functions.
fi

# A number that identifies the local instance.
local_inst_num=$((inst_base + inst_inc*local_ordinal))

# Assume that the version is the same for all instances.
version=$(grep "^# *version *=" "${conf}" | sed "s/^.*=//g")

# If an input ads_truststore was specified extract a certificate from it.
cert="${tmp_dir}/cert.pem"
if [ ! -z ${ads_truststore} ]; then
  log "Extracting certificate from \"${ads_truststore}\"."
  "${mcerts}" export-certificate --keystore "${ads_truststore}" \
    --keystore-password-file "${ads_truststore}".pin --alias ads-certificate \
    --output-file "${cert}" --output-format PEM
else
  log "\"ads_truststore\" not specified - new certificates will not be added."
  true > "${cert}"
fi

# Convert the contents of "${cert}" to a single line base 64 encoded string
# suitable for an LDIF "::" attributes. Not that this will be an empty string
# in the case where "ads_truststore" was not specified (see above). Note that
# this specifically does not use PD's "base64" since that has a different
# syntax.
cert_base64=$(/bin/base64 < "${cert}" | tr -d \\012)

# Capture the comment header (all comments at the start of config/config.ldif)
# before any of the CLIs change it.
header="${tmp_dir}/header.txt"
sed -n "/^#/,/^[^#]/p" < "${conf}" | grep "^#" > "${header}"

regions_file="${tmp_dir}/regions.txt"
jq -r 'keys_unsorted | .[]' "${descriptor_json}" > "${regions_file}"
if grep -q ' ' "${regions_file}"
then
  fatal "Regions file \"${regions_file}\" contains a space."
fi
regions=$(cat "${regions_file}")

# Extract the local server instance base entry. It will be used as a
# template for the other instances.
template="${tmp_dir}/template.ldif"
si_dn="cn=${local_hostname}-${local_inst_num},cn=Server Instances,cn=Topology,cn=config"
si_dn_quoted=$(escape_regex "${si_dn}") # Quoted for regex.
if [ ! -z "${existing_local_server_as_template}" ] && \
  grep -q "^ *dn: *${si_dn_quoted}$" "${conf}"; then
  log "Creating template from existing local server instance DN \"${si_dn}\"."
  sed -n "/^ *dn: *${si_dn_quoted}$/,/^$/p" "${conf}" | grep -v '^$' | \
    sed "s/${local_hostname}-${local_inst_num}/\${hostname}-\${inst_num}/g; \
       s/\(^ *dn: .*\)/\1\nchangeType: add/g" | \
       grep -v "^ *ds-cfg-replication-domain-server-id *:" | \
       grep -v "^ *ds-cfg-replication-server-id *:" | \
       grep -v "^ *ds-cfg-ldap-port *:" | \
       grep -v "^ *ds-cfg-replication-port *:" | \
       grep -v "^ *ds-cfg-base-dn *:" | \
       grep -v "^ *ds-cfg-cluster-name *:" | \
       grep -v "^ *ds-cfg-server-instance-name *:" | \
       grep -v "^ *ds-cfg-hostname *:" | \
       grep -v "^ *ds-cfg-server-instance-location *:" | \
       grep -v "^ *ds-cfg-inter-server-certificate *:" | \
       grep -v "^ *createTimestamp *:" | \
       grep -v "^ *creatorsName *:" | \
       grep -v "^ *modifyTimestamp *:" | \
       grep -v "^ *modifiersName *:" | \
       grep -v "^ *entryUUID *:" > "${template}"
else
  if [ ! -z "${existing_local_server_as_template}" ]; then
    log "No existing local server instance DN \"${si_dn}\". Using saved template."
  else
    log "Not using existing local server instance DN \"${si_dn}\". Using saved template."
  fi
  if [ -z ${cert_base64} ]; then
    fatal "A certificate is needed for new local server instance DN \
\"${si_dn}\", but no \"ads_truststore\" was specified."
  fi
  cat <<EOF > "${template}"
dn: cn=\${hostname}-\${inst_num},cn=Server Instances,cn=Topology,cn=config
changeType: add
objectClass: ds-cfg-branch
objectClass: ds-mirrored-object
objectClass: top
objectClass: ds-cfg-server-instance
objectClass: ds-cfg-data-store-server-instance
cn: \${hostname}-\${inst_num}
ds-cfg-server-root: ${inst_root}
ds-cfg-server-version: ${version}
EOF
fi

# Replaced values for all templates.
cat <<EOF >> "${template}"
ds-cfg-cluster-name: Directory Server
ds-cfg-server-instance-name: \${hostname}-\${inst_num}
ds-cfg-inter-server-certificate:: ${cert_base64}
ds-cfg-server-instance-location: \${region}
ds-cfg-hostname: \${hostname}
EOF

# Add the server and replica IDs to the template.
cat << EOF >> "${template}"
ds-cfg-replication-server-id: \${server_id}
ds-cfg-ldap-port: \${ldap_port}
ds-cfg-ldaps-port: \${ldaps_port}
ds-cfg-replication-port: \${repl_port}
EOF

# Modifications to be applied to config.ldif.
mods="${tmp_dir}/mods.ldif"

# Brand new never started instances need this DN created.
si_top_dn="cn=Server Instances,cn=Topology,cn=config"
if grep -q "^ *dn: *${si_top_dn}$" < "${conf}"; then
  log "Top level server instance DN \"${si_top_dn}\" already exists."
else
  log "Creating top level server instance DN \"${si_top_dn}\"."
cat <<EOF > "${mods}"
dn: cn=Server Instances,cn=Topology,cn=config
changeType: add
objectClass: ds-cfg-branch
objectClass: ds-mirrored-object
objectClass: top
cn: Server Instances

EOF
fi

# Members of the replication group.
replication_members=""
for region in ${regions}; do
  # Get the hostname for this region.
  hostname_template=$(jq -r ".[\"${region}\"].hostname" "${descriptor_json}")

  # The count of the number of replicas in this region.
  count=$(jq -r ".[\"${region}\"].replicas" "${descriptor_json}")

  ordinal=0
  while [ ${ordinal} -lt ${count} ]; do
    inst_num=$((inst_base + inst_inc*ordinal))

    # Zero based index into the list of regions.
    region_index=$(set -- $(grep -nxF "${region}" "${regions_file}" | tr : ' '); echo $1)
    region_index=$((region_index - 1)) # zero based
    if [ "$region_index" -eq -1 ]; then
        fatal "Unable to find region \"${region}\" in \"${regions_file}\"."
    fi

    # Hostnames with "${ordinal}", if any, are replaced with the correct ordinal.
    hostname=$(export ordinal; echo "${hostname_template}" | envsubst)

    replica_ids=""
    # Replication IDs base given by ordinal.
    base_dn_index=0
    for base_dn in "$@"; do
      replica_id=$((repl_id_base + repl_id_rinc*region_index + repl_id_inc*ordinal + 2*base_dn_index + 1)) # odd
      replica_ids="${replica_ids} ${replica_id}"
      base_dn_index=$((base_dn_index + 1))
    done
    server_id=$((repl_id_base + repl_id_rinc*region_index + repl_id_inc*ordinal)) # even

    # The LDAP port to use.
    ldap_port=$((ldap_port_base + ldap_port_inc*ordinal))

    # The LDAPS port to use.
    ldaps_port=$((ldaps_port_base + ldaps_port_inc*ordinal))

    # The replication port to use.
    repl_port=$((repl_port_base + repl_port_inc*ordinal))

    # Separate from the previous modification if not the first.
    if [ ${ordinal} -gt 0 ]; then
      echo >> "${mods}"
    fi

    # Save the local version of the IDs for later if both the ordinal and the region match the local values.
    if [ ${ordinal} -eq ${local_ordinal} ] && [ ${region} = ${local_region} ] ; then
      expected_local_inst_num=${inst_num}
      local_replica_ids=${replica_ids}
      local_server_id=${server_id}
      local_ldap_port=${ldap_port}
      local_ldaps_port=${ldaps_port}
      local_repl_port=${repl_port}
    fi

    # More sophisticated quoting could be done, but won't be needed unless
    # unusual characters are used for the name.
    si_cn="${hostname}-${inst_num}"
    replication_members="${replication_members} ${si_cn}"
    si_dn="cn=${si_cn},cn=Server Instances,cn=Topology,cn=config"
    si_dn_quoted=$(escape_regex "${si_dn}") # Quoted for regex.

    # Check if the instance already exists.
    if grep -q "^ *dn: *${si_dn_quoted}$" < "${conf}"; then
      log "Updating existing server instance DN \"${si_dn}\"."
      cat << EOF >> "${mods}"
dn: ${si_dn}
changeType: modify
replace: ds-cfg-replication-server-id
ds-cfg-replication-server-id: ${server_id}
-
replace: ds-cfg-hostname
ds-cfg-hostname: ${hostname}
-
replace: ds-cfg-ldap-port
ds-cfg-ldap-port: ${ldap_port}
-
replace: ds-cfg-ldaps-port
ds-cfg-ldaps-port: ${ldaps_port}
-
replace: ds-cfg-replication-port
ds-cfg-replication-port: ${repl_port}
-
replace: ds-cfg-replication-domain-server-id
EOF
      for replica_id in ${replica_ids}; do
        echo "ds-cfg-replication-domain-server-id: ${replica_id}" >> "${mods}"
      done
    else
      log "Adding new server instance DN \"${si_dn}\"."

      # Subshell to avoid polluting environment variables.
      (export hostname region ordinal inst_num server_id ldap_port ldaps_port repl_port; envsubst < \
        "${template}" >> "${mods}")
      for replica_id in ${replica_ids}; do
        echo "ds-cfg-replication-domain-server-id: ${replica_id}" >> "${mods}"
      done
    fi
    ordinal=$((ordinal + 1))
  done
done

# Make sure the inst number calculation is consistent. This should not fail.
if [ $local_inst_num -ne $expected_local_inst_num ]; then
  fatal "local_inst_num=$local_inst_num is not equal to \
expected_local_inst_num=$expected_local_inst_num"
fi

# Add non-topology replication entries.

# Similar to the logic for replication IDs.
repl_port=$((repl_port_base + repl_port_inc*local_ordinal))

# The DN of the replication server. This does not need to be quoted since it has
# no special characters.
rs_dn="cn=replication server,cn=Multimaster Synchronization,cn=Synchronization Providers,cn=config"

if grep -q "^ *dn: *${rs_dn}$" < "${conf}"; then
  log "Updating existing replication entries for replication server \
DN \"${rs_dn}\"."
  cat << EOF >> "${mods}"

dn: ${rs_dn}
changeType: modify
replace: ds-cfg-replication-server-id
ds-cfg-replication-server-id: ${local_server_id}
-
replace: ds-cfg-replication-port
ds-cfg-replication-port: ${local_repl_port}
EOF
else
  log "Adding new replication entries for replication server DN \"${rs_dn}\"."
  cat << EOF >> "${mods}"

dn: ${rs_dn}
changeType: add
objectClass: ds-cfg-replication-server
objectClass: top
ds-cfg-replication-db-directory: changelogDb
cn: replication server
ds-cfg-replication-server-id: ${local_server_id}
ds-cfg-gateway-priority: 5
ds-cfg-replication-port: ${local_repl_port}
ds-cfg-replication-purge-minimum-retain-count: 1000
ds-cfg-replication-purge-delay: 86400 s
EOF
fi
replica_index=0
for base_dn in "$@"; do
  escaped_base_dn=$(escape_dn "${base_dn}")
  domain_dn="cn=${escaped_base_dn},cn=domains,cn=Multimaster Synchronization,\
cn=Synchronization Providers,cn=config"
  # Pretend local_replica_ids is a zero based array where each token is an
  # array element. Get the element at index replica_index.
  local_replica_id=$(set -- ${local_replica_ids}; eval echo \${$((replica_index + 1))})

  if grep -q "^ *dn: *${domain_dn}$" < "${conf}"; then
    log "Updating existing replication domain ${base_dn}."
    cat << EOF >> "${mods}"

dn: ${domain_dn}
changeType: modify
replace: ds-cfg-server-id
ds-cfg-server-id: ${local_replica_id}
-
replace: cn
cn: ${escaped_base_dn}
-
replace: ds-cfg-base-dn
ds-cfg-base-dn: ${base_dn}
EOF
  else
    log "Adding new replication domain ${base_dn}."
    cat << EOF >> "${mods}"

dn: ${domain_dn}
changeType: add
objectClass: top
objectClass: ds-cfg-replication-domain
ds-cfg-server-id: ${local_replica_id}
cn: ${escaped_base_dn}
ds-cfg-base-dn: ${base_dn}
EOF
  fi
  replica_index=$((replica_index + 1))
done

# Apply the list of modifications above to the configuration in order to produce
# a new configuration.
log "Calling \"${ldifmodify}\" for mods \"${mods}\"."
"${ldifmodify}" -s "${conf}" -m "${mods}" -t "${conf}.new"

# Since the above was successful move the new configuration into place so that
# dsconfig can act on it.
mv -f "${conf}.new" "${conf}"

# Remove zero ports (unused ports).
conf_no_zero_ports="${tmp_dir}/conf-no-zero-ports.ldif"
grep -vE "^ *ds-cfg-(ldap|ldaps|replication)-port *: * 0 *$" "${conf}" > \
  "${conf_no_zero_ports}"
lines_with=$(set -- $(wc -l "${conf}"); echo $1)
lines_without=$(set -- $(wc -l "${conf_no_zero_ports}"); echo $1)
lines_removed=$((lines_with - lines_without))
if [ ${lines_removed} -gt 0 ]; then
  mv -f "${conf_no_zero_ports}" "${conf}"
  log "Removed ${lines_removed} zero (unused) ports from ${conf}."
else
  log "There are no zero (unused) ports in ${conf}."
fi

admin_dn="cn=admin,cn=Topology Admin Users,cn=topology,cn=config"
if grep -q "^ *dn: *${admin_dn}$" < "${conf}"; then
  log "Admin user \"admin\" already exists."
else
  # Create the topology admin user with the password from admin_pass_file.
  log "Creating topology admin user \"admin\"."
  "${dsconfig}" -n --offline --suppressMirroredDataChecks create-topology-admin-user \
    --user-name "${admin_user}" \
    --set alternate-bind-dn:cn=admin \
    --set "alternate-bind-dn:cn=admin,cn=Administrators,cn=admin data" \
    --set "password<${admin_pass_file}" \
    --set user-id:admin \
    --set inherit-default-root-privileges:true
fi

group_dn="cn=replication-servers,cn=Server Groups,cn=topology,cn=config"
if grep -q "^ *dn: *${group_dn}$" < "${conf}"; then
  # The group already exists.
  subcommand="set-server-group-prop"
  verb="Updating"
else
  # Create a new group.
  subcommand="create-server-group"
  verb="Creating"
fi
# A list "--set member ..." arguments.
set_member_args=""
for replication_member in ${replication_members}; do
  inst_num=$((inst_base + inst_inc*ordinal))
  set_member_args="${set_member_args} --set member:${replication_member}"
  ordinal=$((ordinal + 1))
done

# Add the instances created to a group of replication servers.
log "${verb} replication groups for members: ${replication_members}."
"${dsconfig}" -n --offline --suppressMirroredDataChecks "${subcommand}" \
  --group-name replication-servers \
  ${set_member_args}

# If an ads_truststore was specified then copy it into place. Note that this
# was needed prior to DS-42439, and in external instances of test
# OfflineEnableTest where "setup" is not run, which is needed for DS-42439.
if [ ! -z ${ads_truststore} ]; then
  log "Copying truststore if needed."
  if [ ! -f "${ads_truststore}" ]; then
    fatal "ads_truststore \"${ads_truststore}\" specified does not exist."
  fi

  # Only copy it if it is different.
  if ! diff -q "${ads_truststore}" "${inst_root}/config" &> /dev/null; then
    # It's different, so copy the file.
    cp -f "${ads_truststore}"   "${inst_root}/config"
    cp -f "${ads_truststore}.pin" "${inst_root}/config"
    log "Truststore \"${ads_truststore}\" copied."
  else
    # It's the same.
    log "Truststore \"${ads_truststore}\" not changed. Not copied."
  fi
fi

# Restore the original header.
log "Restoring the orignal header."
conf_no_header="${tmp_dir}/conf-no-header.ldif"
sed -n '/^[^#]/,$p' < "${conf}" > "${conf_no_header}"
cat "${header}" "${conf_no_header}" > "${conf}"

# The preferred permissions.
chmod 600 "${conf}"

log "End for \"${inst_root}\"."
