#!/usr/bin/env sh

# Copyright 2020 Ping Identity Corporation
# All Rights Reserved.

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

# This a wrapper for 185-offline-enable.sh. To enable replication offline, call
# this script without any arguments.

if is_multi_cluster; then
  # Multi-region

  # For multi-region the descriptor file must exist.
  if [ ! -f "${TOPOLOGY_DESCRIPTOR_JSON}" ] || [ ! -s "${TOPOLOGY_DESCRIPTOR_JSON}" ]; then
    beluga_log "${TOPOLOGY_DESCRIPTOR_JSON} file is required in multi-cluster mode but does not exist or is empty"
    exit 1
  fi

  # NLB settings:
  # PD_PORT_INC=1

  # VPC peer settings (same as single-region case):
  PD_PORT_INC=0

else
  # Single-region

  # For single-region it's possible to generate a descriptor if one does not exist.
  if [ ! -f "${TOPOLOGY_DESCRIPTOR_JSON}" ] || [ ! -s "${TOPOLOGY_DESCRIPTOR_JSON}" ]; then
    beluga_log "${TOPOLOGY_DESCRIPTOR_JSON} does not exist or is empty in single-cluster mode - creating it"

    # The total number of replicating pods.
    NUM_REPLICAS=$(kubectl get statefulset "${K8S_STATEFUL_SET_NAME}" -o jsonpath='{.spec.replicas}')

    cat <<EOF > "${TOPOLOGY_DESCRIPTOR_JSON}"
{
    "${REGION}": {
        "hostname": "${PD_CLUSTER_DOMAIN_NAME}",
        "replicas": ${NUM_REPLICAS}
    }
}
EOF
  else
    beluga_log "${TOPOLOGY_DESCRIPTOR_JSON} already exists:"
  fi

  # For single region, the hostnames are different, but the ports are the same.
  PD_PORT_INC=0
fi

beluga_log "Topology descriptor JSON file '${TOPOLOGY_DESCRIPTOR_JSON}' contents:"
cat "${TOPOLOGY_DESCRIPTOR_JSON}"
echo

# The basis for the LDAP(S) and replication port numbers to use.
PD_LDAP_PORT_BASE=$((PD_LDAP_PORT - PD_PORT_INC * ORDINAL))
PD_LDAPS_PORT_BASE=$((PD_LDAPS_PORT - PD_PORT_INC * ORDINAL))
PD_REPL_PORT_BASE=$((PD_REPL_PORT - PD_PORT_INC * ORDINAL))

# Build the offline-enable.sh configuration.
offline_enable_config=$(mktemp -t "offline-enable-config-XXXXXXXXXX")
cat > "${offline_enable_config}" <<EOF
{
  "descriptor_json" : \"${TOPOLOGY_DESCRIPTOR_JSON}\",
  "inst_root"       : \"${SERVER_ROOT_DIR}\",
  "local_region"    : \"${REGION}\",
  "local_ordinal"   : ${ORDINAL},
  "inst_base"       : 0,
  "inst_inc"        : 1,
  "repl_id_base"    : 1000,
  "repl_id_rinc"    : 1000,
  "repl_id_inc"     : 100,
  "ldap_port_base"  : ${PD_LDAP_PORT_BASE},
  "ldap_port_inc"   : ${PD_PORT_INC},
  "ldaps_port_base" : ${PD_LDAPS_PORT_BASE},
  "ldaps_port_inc"  : ${PD_PORT_INC},
  "repl_port_base"  : ${PD_REPL_PORT_BASE},
  "repl_port_inc"   : ${PD_PORT_INC},
  "ads_truststore"  : "none",
  "admin_user"      : \"${ADMIN_USER_NAME}\",
  "admin_pass_file" : \"${ADMIN_USER_PASSWORD_FILE}\"
}
EOF

beluga_log "Offline enable configuration:"
cat "${offline_enable_config}"

# Enable replication offline before the instances are started.
cp -f "${SERVER_ROOT_DIR}/config/config.ldif" "${SERVER_ROOT_DIR}/config/config.ldif.before"
"${HOOKS_DIR}"/185-offline-enable.sh -v "${offline_enable_config}" ${DNS_TO_INITIALIZE}
cp -f "${SERVER_ROOT_DIR}/config/config.ldif" "${SERVER_ROOT_DIR}/config/config.ldif.after"

# Remove temporary files.
rm -f "${offline_enable_config}"