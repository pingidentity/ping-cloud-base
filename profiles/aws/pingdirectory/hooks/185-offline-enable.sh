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
# Updates instance-name in global config cn=config
#
# Administrative user "admin":
#   cn=Topology Admin Users,cn=Topology,cn=config
#   cn=admin,cn=Topology Admin Users,cn=Topology,cn=config
#
# Server group "replication-servers":
# members of the "replication-servers" group:
#   cn=Server Groups,cn=Topology,cn=config
#   cn=replication-servers,cn=Server Groups,cn=Topology,cn=config
#
# Server group "all-servers":
# members of the "all-servers" group:
#   cn=Server Groups,cn=Topology,cn=config
#   cn=all-servers,cn=Server Groups,cn=Topology,cn=config

# Globals

bname="${0##*/}"
tmp_dir=$(mktemp -td "${bname}.XXXXXXXXXX")

# The configuration parameters passed to this script via a JSON configuration file.
params="descriptor_json \
  inst_root \
  hostname_prefix \
  local_tenant_domain \
  local_region \
  local_num_replicas \
  local_ordinal \
  repl_id_base \
  repl_id_rinc \
  repl_id_inc \
  https_port_base \
  ldap_port_base \
  ldaps_port_base \
  repl_port_base \
  port_inc \
  ads_crt_file \
  admin_user \
  admin_pass_file"

# Functions

# Escape base DNs so that they can appear in LDIF.
escape_dn() {
  local dn="$1"
  echo "${dn}" | tr ',=' "__"
}

# Escape strings so that they can appear in grep.
escape_regex() {
  local str="$1"
  echo "${str}" | sed 's/\([.^$]\)/\\\1/g'
}

### Main Entry ###

config_json="$1"

# After the following shift the base DNs will be in position parameters $1, $2 ...
shift

for param in ${params}; do
  value=$(jq -r ".${param}" "${config_json}")
  if [ -z "${value}" ] || [ "${value}" = 'null' ]; then
    beluga_log "Parameter '${param}' is missing from configuration file '${config_json}'"
    exit 1
  fi
  eval $param=\"\${value}\"
done

beluga_log "Begin for '${inst_root}'"

# Paths relative to the install directory.
conf="${inst_root}/config/config.ldif"

# Assume that the version is the same for all instances.
version=$(grep "^# *version *=" "${conf}" | sed "s/^.*=//g")

# Convert the contents of the ADS cert to a single line base 64 encoded string
# suitable for an LDIF "::" attribute. Note that this specifically does not
# use PD's "base64" since that has a different syntax.
if [ ! -f "${ads_crt_file}" ] || [ ! -s "${ads_crt_file}" ]; then
  beluga_log "A certificate is needed for new local server instance, but none was specified"
  exit 1
fi
cert_base64=$(/bin/base64 < "${ads_crt_file}" | tr -d \\012)

# Capture the comment header (all comments at the start of config/config.ldif)
# before any of the CLIs change it.
header="${tmp_dir}/header.txt"
sed -n "/^#/,/^[^#]/p" < "${conf}" | grep "^#" > "${header}"

regions_file="${tmp_dir}/regions.txt"
jq -r 'keys_unsorted | .[]' "${descriptor_json}" > "${regions_file}"

if grep -q ' ' "${regions_file}"; then
  beluga_log "Regions file '${regions_file}' contains a space"
  exit 1
fi

regions=$(cat "${regions_file}")
for region in ${regions}; do
  hostname_from_desc_file=$(jq -r ".[\"${region}\"].hostname" "${descriptor_json}")
  if test "${region}" = "${local_region}" ||
    $(echo "${hostname_from_desc_file}" | grep -qi "${local_tenant_domain}"); then
    local_region="${region}"
    local_hostname="${hostname_from_desc_file}"
    local_count=$(jq -r ".[\"${local_region}\"].replicas" "${descriptor_json}")
    break
  fi
done

if [ -z "${local_hostname}" ]; then
  beluga_log "Hostname for local cluster does not exist in the topology descriptor file"
  exit 1
fi

if [ "${local_num_replicas}" -ne "${local_count}" ]; then
  beluga_log "Mismatch in replicas for ${region} - expected: ${local_num_replicas}, actual: ${local_count}"
  exit 1
fi

# Determine the number of local replicas
beluga_log "local_region: ${local_region}"
beluga_log "local_hostname: ${local_hostname}"
beluga_log "local_count: ${local_count}"

# Extract the local server instance base entry. It will be used as a
# template for the other instances.
template="${tmp_dir}/template.ldif"

# If the port increment is 0, then that means that the names of the servers are unique.
# So prepend the hostname_prefix to the hostname from the descriptor file.
if [ "${port_inc}" -eq 0 ]; then
  if [ -z "${hostname_prefix}" ]; then
    beluga_log "hostname_prefix must be specified when port_inc is 0"
    exit 1
  fi
  ds_cfg_hostname="${hostname_prefix}-\${ordinal}.\${hostname}"
  ds_cfg_server_instance_name="${hostname_prefix}-\${ordinal}.\${hostname}"
  local_inst_name="${hostname_prefix}-${local_ordinal}.${local_hostname}"
else
  ds_cfg_hostname="\${hostname}"
  ds_cfg_server_instance_name="\${hostname}-\${ordinal}"
  local_inst_name="${local_hostname}-${local_ordinal}"
fi

cat <<EOF > "${template}"
dn: cn=${ds_cfg_server_instance_name},cn=Server Instances,cn=Topology,cn=config
changeType: add
objectClass: ds-cfg-branch
objectClass: ds-mirrored-object
objectClass: top
objectClass: ds-cfg-server-instance
objectClass: ds-cfg-data-store-server-instance
cn: ${ds_cfg_server_instance_name}
ds-cfg-server-root: ${inst_root}
ds-cfg-server-version: ${version}
ds-cfg-cluster-name: cluster_${ds_cfg_server_instance_name}
ds-cfg-server-instance-name: ${ds_cfg_server_instance_name}
ds-cfg-inter-server-certificate:: ${cert_base64}
ds-cfg-server-instance-location: \${region}
ds-cfg-hostname: ${ds_cfg_hostname}
ds-cfg-replication-server-id: \${server_id}
ds-cfg-ldap-port: \${ldap_port}
ds-cfg-ldaps-port: \${ldaps_port}
ds-cfg-https-port: \${https_port}
ds-cfg-replication-port: \${repl_port}
EOF

# Modifications to be applied to config.ldif.
mods="${tmp_dir}/mods.ldif"
rm -f "${mods}"

# Remove all existing server instances
si_top_dn="cn=Server Instances,cn=Topology,cn=config"

beluga_log "Removing all existing server instances"
grep -i "^dn:.*${si_top_dn}$" < "${conf}" | tac |
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
  hostname=$(jq -r ".[\"${region}\"].hostname" "${descriptor_json}")

  # The count of the number of replicas in this region.
  count=$(jq -r ".[\"${region}\"].replicas" "${descriptor_json}")

  ordinal=0
  while [ "${ordinal}" -lt "${count}" ]; do
    # Zero based index into the list of regions.
    region_index=$(set -- $(grep -nxF "${region}" "${regions_file}" | tr : ' '); echo $1)
    region_index=$((region_index - 1)) # zero based
    if [ "$region_index" -eq -1 ]; then
      beluga_log "Unable to find region '${region}' in '${regions_file}'"
      exit 1
    fi

    # Replication IDs base given by ordinal.
    replica_ids=""
    base_dn_index=0

    for base_dn in "$@"; do
      replica_id=$((repl_id_base + repl_id_rinc * region_index + repl_id_inc * ordinal + 2 * base_dn_index + 1)) # odd
      replica_ids="${replica_ids} ${replica_id}"
      base_dn_index=$((base_dn_index + 1))
    done

    server_id=$((repl_id_base + repl_id_rinc * region_index + repl_id_inc * ordinal)) # even

    # The ports to use.
    https_port=$((https_port_base + port_inc * ordinal))
    ldap_port=$((ldap_port_base + port_inc * ordinal))
    ldaps_port=$((ldaps_port_base + port_inc * ordinal))
    repl_port=$((repl_port_base + port_inc * ordinal))

    # Separate from the previous modification if not the first.
    if [ "${ordinal}" -gt 0 ]; then
      echo >> "${mods}"
    fi

    # Save the local version of the IDs for later if both the ordinal and the region match the local values.
    if [ "${ordinal}" -eq "${local_ordinal}" ] && [ "${region}" = "${local_region}" ] ; then
      expected_local_ordinal=${ordinal}
      local_replica_ids=${replica_ids}
      local_server_id=${server_id}
      local_repl_port=${repl_port}
    fi

    # More sophisticated quoting could be done, but won't be needed unless
    # unusual characters are used for the name.
    [ "${port_inc}" -eq 0 ] &&
      si_cn="${hostname_prefix}-${ordinal}.${hostname}" ||
      si_cn="${hostname}-${ordinal}"
    replication_members="${replication_members} ${si_cn}"

    # Subshell to avoid polluting environment variables.
    (export hostname region ordinal server_id ldap_port ldaps_port https_port repl_port; envsubst < \
      "${template}" >> "${mods}")
    for replica_id in ${replica_ids}; do
      echo "ds-cfg-replication-domain-server-id: ${replica_id}" >> "${mods}"
    done

    # Add a new line after each server instance entry
    echo >> "${mods}"

    ordinal=$((ordinal + 1))
  done
done

# Make sure the inst number calculation is consistent. This should not fail.
if [ "${local_ordinal}" -ne "${expected_local_ordinal}" ]; then
  beluga_log "local_ordinal=${local_ordinal} is not equal to expected_local_ordinal=${expected_local_ordinal}"
  exit 1
fi

beluga_log "Replacing local server instance name to '${si_top_dn}'"
cat <<EOF >> "${mods}"

dn: cn=config
changeType: modify
replace: ds-cfg-instance-name
ds-cfg-instance-name: ${local_inst_name}

EOF

# Add non-topology replication entries.

# Similar to the logic for replication IDs.
repl_port=$((repl_port_base + port_inc * local_ordinal))

# The DN of the replication server. This does not need to be quoted since it has
# no special characters.
rs_dn="cn=replication server,cn=Multimaster Synchronization,cn=Synchronization Providers,cn=config"

if grep -qi "^ *dn: *${rs_dn}$" < "${conf}"; then
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

beluga_log "removing DNs no longer being replicated"
domains_dn='cn=domains,cn=Multimaster Synchronization,cn=Synchronization Providers,cn=config'

grep -i "^dn:.*${domains_dn}$" < "${conf}" |
while read -r dn; do
  # Skip the 'domains' container DN
  echo "${dn}" | grep -qi "^dn: ${domains_dn}$" && continue

  # Check if the DN is still being replicated.
  is_replicated=false
  for base_dn in "$@"; do
    escaped_base_dn=$(escape_dn "${base_dn}")
    domain_dn="cn=${escaped_base_dn},${domains_dn}"

    if $(echo "${dn}" | grep -qi "^dn: ${domain_dn}$"); then
      is_replicated=true
      break
    fi
  done

  # DN is still being replicated - must not remove
  "${is_replicated}" && continue

  # DN is no longer being replicated - must remove
  beluga_log "'${dn}' is no longer being replicated - will remove"
  cat >> "${mods}" << EOF
${dn}
changeType: delete

EOF
done

replica_index=0
for base_dn in "$@"; do
  escaped_base_dn=$(escape_dn "${base_dn}")
  domain_dn="cn=${escaped_base_dn},${domains_dn}"
  # Pretend local_replica_ids is a zero based array where each token is an
  # array element. Get the element at index replica_index.
  local_replica_id=$(set -- ${local_replica_ids}; eval echo \${$((replica_index + 1))})

  if grep -qi "^ *dn: *${domain_dn}$" < "${conf}"; then
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
if test $? -ne 0; then
  beluga_log "error applying modifications in ${mods}"
  exit 1
fi

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

config_batch_file="${tmp_dir}/batch.dsconfig"

admin_dn="cn=admin,cn=Topology Admin Users,cn=Topology,cn=config"
if grep -qi "^ *dn: *${admin_dn}$" < "${conf}"; then
  beluga_log "Admin user 'admin' already exists."
else
  # Create the topology admin user with the password from admin_pass_file.
  beluga_log "Creating topology admin user 'admin'"
  cat > "${config_batch_file}" <<EOF
dsconfig create-topology-admin-user \\
  --user-name "${admin_user}" \\
  --set alternate-bind-dn:cn=admin \\
  --set "alternate-bind-dn:cn=admin,cn=Administrators,cn=admin data" \\
  --set "password<${admin_pass_file}" \\
  --set user-id:admin \\
  --set inherit-default-root-privileges:true

EOF
fi

# Add the instances created to a group of replication servers.
for group in replication-servers all-servers; do
  group_dn="cn=${group},cn=Server Groups,cn=Topology,cn=config"

  if grep -qi "^ *dn: *${group_dn}$" < "${conf}"; then
    # The group already exists.
    beluga_log "group '${group}' already exists"
    subcommand="set-server-group-prop"
    verb="Updating"
  else
    # Create a new group.
    beluga_log "group '${group}' does not already exist - creating"
    subcommand="create-server-group"
    verb="Creating"
  fi

  # A list "--set member ..." arguments.
  set_member_args=""
  for replication_member in ${replication_members}; do
    set_member_args="${set_member_args} --set member:${replication_member}"
    ordinal=$((ordinal + 1))
  done

  beluga_log "${verb} '${group}' group with members: ${replication_members}."
  cat >> "${config_batch_file}" <<EOF
dsconfig ${subcommand} \\
  --group-name "${group}" \\
  ${set_member_args}

EOF
done

beluga_log "applying dsconfig from file ${config_batch_file}:"
cat "${config_batch_file}"
dsconfig --no-prompt --offline --suppressMirroredDataChecks --batch-file "${config_batch_file}"
if test $? -ne 0; then
  beluga_log "error applying dsconfig commands in ${config_batch_file}"
  exit 1
fi

# Restore the original header.
beluga_log "restoring the original header"
conf_no_header="${tmp_dir}/conf-no-header.ldif"

sed -n '/^[^#]/,$p' < "${conf}" > "${conf_no_header}"
cat "${header}" "${conf_no_header}" > "${conf}"

# The preferred permissions.
chmod 600 "${conf}"

beluga_log "End for '${inst_root}'"