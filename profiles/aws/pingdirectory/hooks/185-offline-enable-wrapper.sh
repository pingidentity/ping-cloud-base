#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

# This a wrapper for 185-offline-enable.sh. To enable replication offline, call
# this script without any arguments.

########################################################################################################################
# Validate that the provided file is present, non-empty and has valid JSON.
#
# Arguments:
#   $1 -> The file to validate.
#
# Returns:
#   0 -> If the file is valid; 1 -> otherwise.
########################################################################################################################
function is_valid_json_file() {
  local json_file="$1"
  test ! -f "${json_file}" && return 1
  num_keys="$(jq -r '(keys|length)' "${json_file}")"
  test $? -eq 0 && test ! -z "${num_keys}" && test "${num_keys}" -gt 0
}

# The total number of replicating pods.
NUM_REPLICAS=$(kubectl get statefulset "${K8S_STATEFUL_SET_NAME}" -o jsonpath='{.spec.replicas}')

if is_multi_cluster; then
  if is_valid_json_file "${TOPOLOGY_DESCRIPTOR_JSON}"; then
    DESCRIPTOR_FILE="${TOPOLOGY_DESCRIPTOR_JSON}"
  elif is_valid_json_file "${TOPOLOGY_DESCRIPTOR_PROFILES_JSON}"; then
    DESCRIPTOR_FILE="${TOPOLOGY_DESCRIPTOR_PROFILES_JSON}"
  fi
else
  if is_valid_json_file "${TOPOLOGY_DESCRIPTOR_JSON}" ||
     is_valid_json_file "${TOPOLOGY_DESCRIPTOR_PROFILES_JSON}"; then
     beluga_warn 'In single-cluster mode, the user-provided topology descriptor file will be ignored'
  fi
fi

if test -z "${DESCRIPTOR_FILE}"; then
  DESCRIPTOR_FILE="$(mktemp)"
  beluga_log "Topology descriptor file does not exist or is empty - creating it at ${DESCRIPTOR_FILE}"

  tr -d '[:space:]' <<EOF > "${DESCRIPTOR_FILE}"
{
  "${REGION_NICK_NAME}": {
    "hostname": "${PD_CLUSTER_DOMAIN_NAME}",
    "replicas": ${NUM_REPLICAS}
  }
}
EOF

  if is_multi_cluster; then
    beluga_warn 'Topology descriptor file not provided or is empty in multi-cluster mode'
    beluga_warn 'Only the servers in the local cluster will be considered part of the topology'
  fi
else
  beluga_log "${DESCRIPTOR_FILE} already exists - using it"

  beluga_log "Topology descriptor JSON file '${DESCRIPTOR_FILE}' original contents:"
  cat "${DESCRIPTOR_FILE}"

  beluga_log "Substituting variables in '${DESCRIPTOR_FILE}' file"
  TMP_FILE="$(mktemp)"
  envsubst < "${DESCRIPTOR_FILE}" > "${TMP_FILE}"
  DESCRIPTOR_FILE="${TMP_FILE}"
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
  "local_region"        : "${REGION_NICK_NAME}",
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