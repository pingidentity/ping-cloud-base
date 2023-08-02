#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

########################################################################################################################
# Remove tmp directory and files.
########################################################################################################################
cleanUp() {
  # Remove temporary directory.
  rm -rf "${tmp_dir}"
  # Remove temporary offline config file.
  rm -f "${offline_enable_config}"
}

########################################################################################################################
# Validate that the provided file is present, non-empty and has valid JSON.
#
# Arguments:
#   $1 -> The file to validate.
#
# Returns:
#   0 -> If the file is valid; 1 -> otherwise.
########################################################################################################################
is_valid_json_file() {
  local file_path="${1}"
  local hide_from_stdout

  # Opening the JSON file may raise an exception if its empty.
  # This is OK as the offline-enable-wrapper ignores an empty descriptor.json.
  hide_from_stdout=$(python3 "${json_util_script}" "${file_path}" 2>&1)
  return $?
}

json_util_script="${HOOKS_DIR}/offline-mode/json_util.py"
verify_offline_mode_script="${HOOKS_DIR}/offline-mode/verify_descriptor_json.py"
conf="${SERVER_ROOT_DIR}/config/config.ldif"
bname="${0##*/}"
tmp_dir=$(mktemp -td "${bname}.XXXXXXXXXX")

# This guarantees that cleanUp will always run, even if this script exits due to an error
trap "cleanUp" EXIT

### Main Entry ###

# This a wrapper for 185-offline-enable.sh. To enable replication offline, call
# this script without any arguments.

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

beluga_log "Adding DESCRIPTOR_FILE"
cat "${DESCRIPTOR_FILE}"

# Verify that ADS Certificate file is present
if [ ! -f "${ADS_CRT_FILE}" ] || [ ! -s "${ADS_CRT_FILE}" ]; then
  beluga_error "A certificate is needed for new local server instance, but none was specified"
  exit 1
fi

# Add new line \n character to every line within the ads cert file
ads_crt_with_new_line_chars="$(cat "${ADS_CRT_FILE}" | awk '{printf "%s\\n", $0}')"

# Verify the following:
# 1) Each region has a region name without spaces, hostname, and replica count.
# 2) The server local region exists and that PingDirectory Statefulset matches within the descriptor.json file.
python3 "${verify_offline_mode_script}" \
  "${DESCRIPTOR_FILE}" "${REGION_NICK_NAME}" "${NUM_REPLICAS}"
test $? -ne 0 && exit 1

# Assume that the version is the same for all instances.
server_version=$(grep "^# *version *=" "${conf}" | sed "s/^.*=//g")

# Build the offline-enable.sh configuration.
offline_enable_config=$(mktemp -t "offline-enable-config-XXXXXXXXXX")
cat > "${offline_enable_config}" <<EOF
{
  "descriptor_json"               : "${DESCRIPTOR_FILE}",
  "inst_root"                     : "${SERVER_ROOT_DIR}",
  "k8s_statefulset_name"          : "${K8S_STATEFUL_SET_NAME}",
  "local_region"                  : "${REGION_NICK_NAME}",
  "local_ordinal"                 : ${ORDINAL},
  "repl_id_base"                  : 1000,
  "repl_id_pd_pod_limit_idx"      : ${PD_POD_LIMIT_INDEX},
  "repl_id_pd_base_dn_limit_idx"  : ${PD_BASE_DN_LIMIT_INDEX},
  "https_port_base"               : ${PD_HTTPS_PORT},
  "ldap_port_base"                : ${PD_LDAP_PORT},
  "ldaps_port_base"               : ${PD_LDAPS_PORT},
  "repl_port_base"                : ${PD_REPL_PORT},
  "port_inc"                      : 0,
  "base_dns"                      : "${DNS_TO_ENABLE}",
  "ads_crt_with_new_line_chars"   : "${ads_crt_with_new_line_chars}",
  "server_version"                : "${server_version}"
}
EOF

beluga_log "offline enable configuration (excluding ads_cert in sdout):"
# Print the offline_wrapper_file to sdout but without certificate
cat "${offline_enable_config}" | jq 'del(.ads_crt_with_new_line_chars)'

# Enable replication offline before the instances are started.
cp -f "${conf}" "${conf}.before"

"${HOOKS_DIR}"/185-offline-enable.sh "${offline_enable_config}" ${DNS_TO_ENABLE}
offline_enable_status=$?

if test ${offline_enable_status} -ne 0; then
  beluga_error "offline enable failed"
  exit ${offline_enable_status}
fi

cp -f "${conf}" "${conf}.after"

beluga_log "offline enable complete"