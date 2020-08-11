#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

# This a wrapper for 185-offline-enable.sh. To enable replication offline, call
# this script without any arguments.

beluga_log "exporting config settings"
export_config_settings

# The total number of replicating pods.
NUM_REPLICAS=$(kubectl get statefulset "${K8S_STATEFUL_SET_NAME}" -o jsonpath='{.spec.replicas}')

if [ ! -f "${TOPOLOGY_DESCRIPTOR_JSON}" ] || [ ! -s "${TOPOLOGY_DESCRIPTOR_JSON}" ]; then
  beluga_log "${TOPOLOGY_DESCRIPTOR_JSON} does not exist or is empty - creating it"

  DESCRIPTOR_FILE=$(mktemp)
  cat <<EOF > "${DESCRIPTOR_FILE}"
{
  "${REGION}": {
    "hostname": "${PD_CLUSTER_DOMAIN_NAME}",
    "replicas": ${NUM_REPLICAS}
  }
}
EOF

  if is_multi_cluster; then
    beluga_log "WARNING!!! ${TOPOLOGY_DESCRIPTOR_JSON} not provided or is empty in multi-cluster mode"
    beluga_log "WARNING!!! only the servers in the local cluster will be considered part of the topology"
  fi
else
  DESCRIPTOR_FILE="${TOPOLOGY_DESCRIPTOR_JSON}"
  beluga_log "${TOPOLOGY_DESCRIPTOR_JSON} already exists - using it"
fi

beluga_log "Topology descriptor JSON file '${DESCRIPTOR_FILE}' contents:"
cat "${DESCRIPTOR_FILE}"
echo

# Build the offline-enable.sh configuration.
offline_enable_config=$(mktemp -t "offline-enable-config-XXXXXXXXXX")
cat > "${offline_enable_config}" <<EOF
{
  "descriptor_json"     : "${DESCRIPTOR_FILE}",
  "inst_root"           : "${SERVER_ROOT_DIR}",
  "hostname_prefix"     : "${K8S_STATEFUL_SET_NAME}",
  "local_tenant_domain" : "${TENANT_DOMAIN}",
  "local_region"        : "${REGION}",
  "local_num_replicas"  : ${NUM_REPLICAS},
  "local_ordinal"       : ${ORDINAL},
  "repl_id_base"        : 1000,
  "repl_id_rinc"        : 1000,
  "repl_id_inc"         : 100,
  "https_port_base"     : ${PD_HTTPS_PORT},
  "ldap_port_base"      : ${PD_LDAP_PORT},
  "ldaps_port_base"     : ${PD_LDAPS_PORT},
  "repl_port_base"      : ${PD_REPL_PORT},
  "port_inc"            : 0,
  "ads_crt_file"        : "${ADS_CRT_FILE}",
  "admin_user"          : "${ADMIN_USER_NAME}",
  "admin_pass_file"     : "${ADMIN_USER_PASSWORD_FILE}"
}
EOF

beluga_log "offline enable configuration:"
cat "${offline_enable_config}"

# Enable replication offline before the instances are started.
cp -f "${SERVER_ROOT_DIR}/config/config.ldif" "${SERVER_ROOT_DIR}/config/config.ldif.before"

"${HOOKS_DIR}"/185-offline-enable.sh "${offline_enable_config}" ${DNS_TO_ENABLE}
offline_enable_status=$?

if test ${offline_enable_status} -ne 0; then
  beluga_log "offline enable failed"

  # Remove temporary files.
  rm -f "${offline_enable_config}"

  exit ${offline_enable_status}
fi

cp -f "${SERVER_ROOT_DIR}/config/config.ldif" "${SERVER_ROOT_DIR}/config/config.ldif.after"

# Remove temporary files.
rm -f "${offline_enable_config}"

beluga_log "offline enable complete"