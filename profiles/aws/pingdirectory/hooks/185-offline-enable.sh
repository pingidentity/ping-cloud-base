#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

# This script is an adaptation of the definitive version of this script is in the "pingdirectory"
# git repo in this directory:
#   tests/unit-tests/resource/offline-enable.sh
#
# Please make any changes there and run its unit test:
#  ./build.sh -Dtest.classes=OfflineEnableTest test
#
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

# Globals

bname="${0##*/}"
tmp_dir=$(mktemp -td "${bname}.XXXXXXXXXX")

# Maximum values applied to command line arguments.
max_ordinal=99
max_id_base=32700
max_id_inc=100
max_port=65000
max_port_inc=100
max_count=100

# The configuration parameters passed to this script via a JSON configuration file.
params="descriptor_json \
  inst_root \
  local_region \
  local_ordinal \
  inst_base \
  inst_inc \
  repl_id_base \
  repl_id_rinc \
  repl_id_inc \
  ldap_port_base \
  ldap_port_inc \
  ldaps_port_base \
  ldaps_port_inc \
  repl_port_base \
  repl_port_inc \
  ads_truststore \
  admin_user admin_pass_file"

# Functions

# Log error and exit.
fatal() {
  beluga_log "$1"
  exit 1
}

# Escape base DNs so that they can appear in LDIF.
escape_dn() {
  local dn="${1}"
  echo "${dn}" | tr ',=' "__"
}

# Escape strings so that they can appear in grep.
escape_regex() {
  local str="${1}"
  echo "${str}" | sed 's/\([.^$]\)/\\\1/g'
}

### Main Entry ###

config_json="${1}"

# After the following shift the base DNs will be in position parameters $1, $2 ...
shift

for param in ${params}; do
  value=$(jq -r ".${param}" "${config_json}")
  if [ -z "${value}" ] || [ "${value}" = 'null' ]; then
    fatal "Parameter '${param}' is missing from configuration file '${config_json}'"
  fi
  eval $param=\"\${value}\"
done

beluga_log "Begin for '${inst_root}'"

# Paths relative to the install directory.
conf="${inst_root}/config/config.ldif"

# A number that identifies the local instance.
local_inst_num=$((inst_base + inst_inc * local_ordinal))

# Assume that the version is the same for all instances.
version=$(grep "^# *version *=" "${conf}" | sed "s/^.*=//g")

# Convert the contents of "${cert}" to a single line base 64 encoded string
# suitable for an LDIF "::" attributes. Note that this specifically does not
# use PD's "base64" since that has a different syntax.
cert_base64=$(/bin/base64 < "${ADS_CRT_FILE}" | tr -d \\012)

# Capture the comment header (all comments at the start of config/config.ldif)
# before any of the CLIs change it.
header="${tmp_dir}/header.txt"
sed -n "/^#/,/^[^#]/p" < "${conf}" | grep "^#" > "${header}"

regions_file="${tmp_dir}/regions.txt"
jq -r 'keys_unsorted | .[]' "${descriptor_json}" > "${regions_file}"

if grep -q ' ' "${regions_file}"; then
  fatal "Regions file '${regions_file}' contains a space."
fi

regions=$(cat "${regions_file}")
for region in ${regions}; do
  hostname_from_json_file=$(jq -r ".[\"${region}\"].hostname" "${descriptor_json}")
  if $(echo "${hostname_from_json_file}" | grep -q "${TENANT_DOMAIN}"); then
    local_region="${region}"
    break
  fi
done

# Determine the local hostname and count.
local_hostname="${LOCAL_HOST_NAME}"
local_count=$(jq -r ".[\"${local_region}\"].replicas" "${descriptor_json}")

beluga_log "local_hostname: ${local_hostname}"

if [ "${local_ordinal}" -ge "${local_count}" ]; then
  fatal "Local ordinal ${local_ordinal} must be less than count ${count}"
fi

# Extract the local server instance base entry. It will be used as a
# template for the other instances.
template="${tmp_dir}/template.ldif"

si_dn="cn=${local_hostname}-${local_inst_num},cn=Server Instances,cn=Topology,cn=config"
si_dn_quoted=$(escape_regex "${si_dn}") # Quoted for regex.

if [ -z "${cert_base64}" ]; then
  fatal "A certificate is needed for new local server instance DN '${si_dn}', but none was specified."
fi

cat <<EOF > "${template}"
dn: cn=\${hostname},cn=Server Instances,cn=Topology,cn=config
changeType: add
objectClass: ds-cfg-branch
objectClass: ds-mirrored-object
objectClass: top
objectClass: ds-cfg-server-instance
objectClass: ds-cfg-data-store-server-instance
cn: \${hostname}
ds-cfg-server-root: ${inst_root}
ds-cfg-server-version: ${version}
ds-cfg-cluster-name: cluster_\${hostname}
ds-cfg-server-instance-name: \${hostname}
ds-cfg-inter-server-certificate:: ${cert_base64}
ds-cfg-server-instance-location: \${region}
ds-cfg-hostname: \${hostname}
ds-cfg-replication-server-id: \${server_id}
ds-cfg-ldap-port: \${ldap_port}
ds-cfg-ldaps-port: \${ldaps_port}
ds-cfg-replication-port: \${repl_port}
EOF

# Modifications to be applied to config.ldif.
mods="${tmp_dir}/mods.ldif"
rm -f "${mods}"

# Remove all existing server instances
si_top_dn="cn=Server Instances,cn=Topology,cn=config"

beluga_log "Removing all existing server instances"
ldifsearch --dontWrap --baseDN "${si_top_dn}" --searchScope sub \
    --ldifFile "${conf}" '(&)' dn 2>/dev/null | grep '^dn:' | tac |
while read -r dn; do
  cat <<EOF >> "${mods}"
${dn}
changeType: delete

EOF
done

beluga_log "Creating top level server instance DN '${si_top_dn}'"
cat <<EOF >> "${mods}"
dn: cn=Server Instances,cn=Topology,cn=config
changeType: add
objectClass: ds-cfg-branch
objectClass: ds-mirrored-object
objectClass: top
cn: Server Instances

EOF

# Members of the replication group.
replication_members=""
for region in ${regions}; do
  # Get the hostname for this region.
  hostname_template=$(jq -r ".[\"${region}\"].hostname" "${descriptor_json}")

  # The count of the number of replicas in this region.
  count=$(jq -r ".[\"${region}\"].replicas" "${descriptor_json}")

  ordinal=0
  while [ "${ordinal}" -lt "${count}" ]; do
    inst_num=$((inst_base + inst_inc*ordinal))

    # Zero based index into the list of regions.
    region_index=$(set -- $(grep -nxF "${region}" "${regions_file}" | tr : ' '); echo $1)
    region_index=$((region_index - 1)) # zero based
    if [ "$region_index" -eq -1 ]; then
        fatal "Unable to find region \"${region}\" in \"${regions_file}\"."
    fi

    # Hostnames with "${ordinal}", if any, are replaced with the correct ordinal.
    hostname=$(export ordinal; echo "${hostname_template}" | envsubst)
    hostname="${K8S_STATEFUL_SET_NAME}"-${inst_num}.${hostname}

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
    if [ "${ordinal}" -eq "${local_ordinal}" ] && $(echo "${hostname}" | grep -q "${TENANT_DOMAIN}") ; then
      expected_local_inst_num=${inst_num}
      local_replica_ids=${replica_ids}
      local_server_id=${server_id}
      local_ldap_port=${ldap_port}
      local_ldaps_port=${ldaps_port}
      local_repl_port=${repl_port}
    fi

    # More sophisticated quoting could be done, but won't be needed unless
    # unusual characters are used for the name.
    si_cn="${hostname}"
    replication_members="${replication_members} ${si_cn}"

    si_dn="cn=${si_cn},cn=Server Instances,cn=Topology,cn=config"
    si_dn_quoted=$(escape_regex "${si_dn}") # Quoted for regex.

    # Check if the instance already exists.
    beluga_log "Adding new server instance DN '${si_dn}'"

    # Subshell to avoid polluting environment variables.
    (export hostname region ordinal inst_num server_id ldap_port ldaps_port repl_port; envsubst < \
      "${template}" >> "${mods}")
    for replica_id in ${replica_ids}; do
      echo "ds-cfg-replication-domain-server-id: ${replica_id}" >> "${mods}"
    done

    ordinal=$((ordinal + 1))
  done
done

# Make sure the inst number calculation is consistent. This should not fail.
if [ $local_inst_num -ne $expected_local_inst_num ]; then
  fatal "local_inst_num=$local_inst_num is not equal to expected_local_inst_num=$expected_local_inst_num"
fi

beluga_log "Replacing local server instance name to '${si_top_dn}'"
cat <<EOF >> "${mods}"

dn: cn=config
changeType: modify
replace: ds-cfg-instance-name
ds-cfg-instance-name: ${LOCAL_INSTANCE_NAME}

EOF

# Add non-topology replication entries.

# Similar to the logic for replication IDs.
repl_port=$((repl_port_base + repl_port_inc*local_ordinal))

# The DN of the replication server. This does not need to be quoted since it has
# no special characters.
rs_dn="cn=replication server,cn=Multimaster Synchronization,cn=Synchronization Providers,cn=config"

if grep -q "^ *dn: *${rs_dn}$" < "${conf}"; then
  beluga_log "Updating existing replication entries for replication server DN '${rs_dn}'"
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
  beluga_log "Adding new replication entries for replication server DN '${rs_dn}'"
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
  domain_dn="cn=${escaped_base_dn},cn=domains,cn=Multimaster Synchronization,cn=Synchronization Providers,cn=config"
  # Pretend local_replica_ids is a zero based array where each token is an
  # array element. Get the element at index replica_index.
  local_replica_id=$(set -- ${local_replica_ids}; eval echo \${$((replica_index + 1))})

  if grep -q "^ *dn: *${domain_dn}$" < "${conf}"; then
    beluga_log "Updating existing replication domain ${base_dn}."
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
    beluga_log "Adding new replication domain ${base_dn}."
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
beluga_log "Modifications being applied from ${mods} LDIF file:"
cat "${mods}"

beluga_log "Calling ldifmodify for mods '${mods}'"
ldifmodify -s "${conf}" -m "${mods}" -t "${conf}.new"

# Since the above was successful move the new configuration into place so that
# dsconfig can act on it.
mv -f "${conf}.new" "${conf}"

# Remove zero ports (unused ports).
conf_no_zero_ports="${tmp_dir}/conf-no-zero-ports.ldif"
grep -vE "^ *ds-cfg-(ldap|ldaps|replication)-port *: * 0 *$" "${conf}" > "${conf_no_zero_ports}"

lines_with=$(set -- $(wc -l "${conf}"); echo $1)
lines_without=$(set -- $(wc -l "${conf_no_zero_ports}"); echo $1)
lines_removed=$((lines_with - lines_without))

if [ ${lines_removed} -gt 0 ]; then
  mv -f "${conf_no_zero_ports}" "${conf}"
  beluga_log "Removed ${lines_removed} zero (unused) ports from ${conf}."
else
  beluga_log "There are no zero (unused) ports in ${conf}."
fi

admin_dn="cn=admin,cn=Topology Admin Users,cn=topology,cn=config"
if grep -q "^ *dn: *${admin_dn}$" < "${conf}"; then
  beluga_log "Admin user 'admin' already exists."
else
  # Create the topology admin user with the password from admin_pass_file.
  beluga_log "Creating topology admin user 'admin'"
  dsconfig -n --offline --suppressMirroredDataChecks create-topology-admin-user \
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
for group in replication-servers all-servers; do
  beluga_log "${verb} ${group} group for members: ${replication_members}."
  dsconfig -n --offline --suppressMirroredDataChecks "${subcommand}" \
    --group-name "${group}" \
    ${set_member_args}
done

# Restore the original header.
beluga_log "Restoring the original header."
conf_no_header="${tmp_dir}/conf-no-header.ldif"
sed -n '/^[^#]/,$p' < "${conf}" > "${conf_no_header}"
cat "${header}" "${conf_no_header}" > "${conf}"

# The preferred permissions.
chmod 600 "${conf}"

beluga_log "End for '${inst_root}'"