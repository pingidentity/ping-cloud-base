#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

offline_wrapper_json="$1"

# After the following shift the base DNs will be in position parameters $1, $2 ...
shift

bname="${0##*/}"
tmp_dir=$(mktemp -td "${bname}.XXXXXXXXXX")

# Topology files
topology_file="$(mktemp)"
removed_based_dns_topology_file="$(mktemp)"

# Paths relative to the install directory.
conf="${SERVER_ROOT_DIR}/config/config.ldif"

########################################################################################################################
# Remove all servers from topology. This is a defect due to PDO-4937. This logic can be removed once the PingDirectory
# team fixes. The script 'dsreplication enable-with-static-topology' will restore all the appropriate servers back.
########################################################################################################################
remove_topology_servers_config() {

  # Modifications to be applied to config.ldif.
  local mods="${tmp_dir}/mods.ldif"
  rm -f "${mods}"

  # Remove all-servers and replication-servers groups.
  local groups='replication-servers all-servers'

  beluga_log "Deleting server groups: ${groups}"
  for group in ${groups}; do
    group_dn="cn=${group},cn=Server Groups,cn=Topology,cn=config"
    if grep -qi "^ *dn: *${group_dn}$" < "${conf}"; then
      cat <<EOF >> "${mods}"
dn: ${group_dn}
changeType: delete

EOF
    fi
  done

  # Remove all existing server instances
  local si_top_dn="cn=Server Instances,cn=Topology,cn=config"

  beluga_log "Removing all existing server instances"
  grep -i "^dn:.*${si_top_dn}$" < "${conf}" | tac |
  while read -r dn; do
    cat <<EOF >> "${mods}"
${dn}
changeType: delete

EOF
  done

  # Remove all existing multimaster synchronization entries
  local ms_top_dn="cn=domains,cn=Multimaster Synchronization,cn=Synchronization Providers,cn=config"

  beluga_log "Removing all existing multimaster synchronization entries"
  grep -i "^dn:.*${ms_top_dn}$" < "${conf}" | tac |
  while read -r dn; do
    cat <<EOF >> "${mods}"
${dn}
changeType: delete

EOF
  done

  # Remove all existing multimaster synchronization entries
  local rs_top_dn="cn=replication server,cn=Multimaster Synchronization,cn=Synchronization Providers,cn=config"

  beluga_log "Removing all existing multimaster synchronization entries"
  grep -i "^dn:.*${rs_top_dn}$" < "${conf}" | tac |
  while read -r dn; do
    cat <<EOF >> "${mods}"
${dn}
changeType: delete

EOF
  done

  if [ "$(hostname)" = "pingdirectory-0" ]; then
    # Do something if hostname is pingdirectory-0
    echo "The hostname is pingdirectory-0"

    # The DN of the replication server. This does not need to be quoted since it has
    # no special characters.
    rs_dn="cn=replication server,cn=Multimaster Synchronization,cn=Synchronization Providers,cn=config"

    if grep -qi "^ *dn: *${rs_dn}$" < "${conf}"; then
      beluga_log "Updating existing replication entries for replication server DN '${rs_dn}'"
      cat << EOF >> "${mods}"

dn: ${rs_dn}
changeType: modify
replace: ds-cfg-replication-server-id
ds-cfg-replication-server-id: 1000
-
replace: ds-cfg-replication-port
ds-cfg-replication-port: 8989

EOF
    fi

else

# Do something if hostname is pingdirectory-0
    echo "The hostname is pingdirectory-1"

    # The DN of the replication server. This does not need to be quoted since it has
    # no special characters.
    rs_dn="cn=replication server,cn=Multimaster Synchronization,cn=Synchronization Providers,cn=config"

    if grep -qi "^ *dn: *${rs_dn}$" < "${conf}"; then
      beluga_log "Updating existing replication entries for replication server DN '${rs_dn}'"
      cat << EOF >> "${mods}"

dn: ${rs_dn}
changeType: modify
replace: ds-cfg-replication-server-id
ds-cfg-replication-server-id: 1020
-
replace: ds-cfg-replication-port
ds-cfg-replication-port: 8989

EOF
      fi
  fi

  # Apply the list of modifications above to the configuration in order to produce
  # a new configuration.
  if [ -s "${mods}" ]; then
    beluga_log "Modifications being applied from ${mods} LDIF file:"
    cat "${mods}"

    beluga_log "Calling ldifmodify for mods '${mods}'"
    ldifmodify --doNotWrap --stripTrailingSpaces --sourceLDIF "${conf}" --changesLDIF "${mods}" --targetLDIF  "${conf}.new"
    if test $? -ne 0; then
      return 1
    fi

    # Since the above was successful move the new configuration into place so that
    # dsconfig can act on it.
    mv -f "${conf}.new" "${conf}"

    # Remove zero ports (unused ports).
    local conf_no_zero_ports="${tmp_dir}/conf-no-zero-ports.ldif"
    grep -vE "^ *ds-cfg-(ldap|ldaps|replication)-port *: * 0 *$" "${conf}" > "${conf_no_zero_ports}"

    local lines_with=$(set -- $(wc -l "${conf}"); echo $1)
    local lines_without=$(set -- $(wc -l "${conf_no_zero_ports}"); echo $1)
    local lines_removed=$((lines_with - lines_without))

    if [ ${lines_removed} -gt 0 ]; then
      mv -f "${conf_no_zero_ports}" "${conf}"
      beluga_log "Removed ${lines_removed} zero (unused) ports from ${conf}."
    else
      beluga_log "There are no zero (unused) ports in ${conf}."
    fi

    chmod 600 "${conf}"
  fi

  return 0
}

python3 "${HOOKS_DIR}/offline-mode/manage_offline_mode.py" "${offline_wrapper_json}" > "${topology_file}"
if test $? -ne 0; then
  beluga_error "An error occurred constructing topology file for server"
  exit 1
fi

beluga_log "topology file configuration (excluding ads_cert in sdout):"
# Print the topology file to sdout but without certificate
cat "${topology_file}" | jq '.serverInstances[] |= del(.listenerCert)'

# Remove all USER_BASE_DNs within old topology.
# To remove all base_dns simply delete the replicationDomainServerInfos property within the topology_file and pass in the '--allowDisable' flag.
# This is just a workaround due to PDO-4937. This logic can be removed once the PingDirectory team fixes.
beluga_log "Resetting topology in offline-mode by removing all base_dns"
cat "${topology_file}" | jq '.serverInstances[] |= del(.replicationDomainServerInfos)' > "${removed_based_dns_topology_file}"

# Remove all PingDirectory servers that are registered in  the topology. The next 'dsreplication enable-with-static-topology'
# command call will add it back.
if ! remove_topology_servers_config; then
  beluga_error "Resetting servers in the topology"
  exit 1
fi

dsreplication enable-with-static-topology \
  --offline \
  --allowDisable \
  --useSSL \
  --topologyFilePath "${removed_based_dns_topology_file}" \
  --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
  --adminUID "${ADMIN_USER_NAME}" --no-prompt
if test $? -ne 0; then
  beluga_error "An error occurred resetting dsreplication within enable-with-static-topology"
  exit 1
fi

# Concatenate a list of --baseDns to pass in dsreplication command at once
all_base_dns=""
for base_dn in "$@"; do
  all_base_dns="--baseDN ${base_dn} ${all_base_dns}"
done

beluga_log "Applying new topology in offline-mode for all base_dns"
dsreplication enable-with-static-topology \
  --offline \
  --useSSL \
  --topologyFilePath "${topology_file}" \
  --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
  --adminUID "${ADMIN_USER_NAME}" --no-prompt \
  ${all_base_dns}
if test $? -ne 0; then
  beluga_error "An error occurred calling dsreplication enable-with-static-topology"
  exit 1
fi

dsconfig --no-prompt --offline --suppressMirroredDataChecks set-topology-admin-user-prop \
  --user-name "${ADMIN_USER_NAME}" \
  --set password-policy:"Root Password Policy"
if test $? -ne 0; then
  beluga_error "error applying dsconfig command to set admin password policy"
  exit 1
fi