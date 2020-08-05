#!/usr/bin/env sh

# Copyright 2020 Ping Identity Corporation
# All Rights Reserved.

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

########################################################################################################################
# Find the ordinal in a hostname and return that hostname with the ordinal replaced with "${ordinal}".
#
# Arguments
#   ${1} -> The hostname containing an ordinal.
#   ${2} -> The ordinal to look far (an integer).
########################################################################################################################
get_hostname_with_ordinal() {
  local hostname="${1}"
  local ordinal="${2}"

  hostname_ordinal=$(echo ${hostname} | sed "s/^\([^-]*-\)${ordinal}\(\..*\)$/\1\${ordinal}\2/g")
  if [ "${hostname_ordinal}" = "${hostname}" ]; then
    echo "185-offline-enable-wrapper.sh: Hostname \"${hostname}\" does not contain ordinal \"${ordinal}\"." 1>&2
    exit 1
  fi
  echo "${hostname_ordinal}"
}

# This a wrapper for 185-offline-enable.sh. To enable replication offline call
# this script without any arguments.

# A zero base number that identifies this pod (typically appended to the name).
SHORT_HOST_NAME=$(hostname)
ORDINAL=${SHORT_HOST_NAME##*-}

# The total number of replicating pods.
NUM_REPLICAS=$(kubectl get statefulset "${K8S_STATEFUL_SET_NAME}" -o jsonpath='{.spec.replicas}')

# TODO: Where is a good place for common code like this?
# Get the base DNs to enable. Copied from 80-post-start.sh.
DN_LIST=
if test -z "${REPLICATION_BASE_DNS}"; then
  DN_LIST="${USER_BASE_DN}"
else
  echo "${REPLICATION_BASE_DNS}" | grep -q "${USER_BASE_DN}"
  test $? -eq 0 &&
      DN_LIST="${REPLICATION_BASE_DNS}" ||
      DN_LIST="${REPLICATION_BASE_DNS};${USER_BASE_DN}"
fi

# A space separated list of base DNs to enable. Note that this does not support
# spaces.
DNS_TO_INITIALIZE=$(echo "${DN_LIST}" | tr ';' ' ')

# Hostnames and ports are a function fo multi-cluster.
if is_multi_cluster; then
  # Multi-region

  # For multi-region the descriptor file must exist.
  if [ ! -f "${TOPOLOGY_DESCRIPTOR_JSON}" ]; then
    echo "185-offline-enable-wrapper.sh: Topology descriptor JSON \"${TOPOLOGY_DESCRIPTOR_JSON}\" does not exist, \
but is required for multi-region." 1>&2
    exit 1
  fi
  echo "Topology descriptor JSON \"${TOPOLOGY_DESCRIPTOR_JSON}\":"
  cat "${TOPOLOGY_DESCRIPTOR_JSON}"

  # For multi-region:
  # If using NLB to route traffic between the regions, the hostnames will be the same (per region), but the ports will
  # be different. If using VPC peering (i.e. creating a super network of the subnets) for routing traffic between the
  # regions, then each PD server will have a unique hostname but may use the same port.

  # NOTE: If using NLB, then corresponding changes may be required to the 80-post-start.sh script to export port 6360,
  # 6361, etc. on each server in a region. Since we have VPC peering in Ping Cloud, all servers can use the same LDAPS
  # port, i.e. 1636 (so we don't expose 636${ORDINAL} anymore. The PD_LDAP_PORT and PD_REPL_PORT are set in
  # utils.lib.sh. Only the port increment is set in this script.

  # NLB settings:
  # PD_PORT_INC=1

  # VPC peer settings (same as single-region case):
  PD_PORT_INC=0
else
  # Single-region

  # For single-region it's possible to generate a descriptor if one does not exist.
  if [ ! -f "${TOPOLOGY_DESCRIPTOR_JSON}" ]; then
    echo "185-offline-enable-wrapper.sh: Topology descriptor JSON \"${TOPOLOGY_DESCRIPTOR_JSON}\" does not exist. \
Creating with contents:"
    LOCAL_HOSTNAME=$(hostname -f)
    LOCAL_HOSTNAME_TEMPLATE=$(get_hostname_with_ordinal "${LOCAL_HOSTNAME}" "${ORDINAL}")

    NUM_REPLICAS=$(kubectl get statefulset "${K8S_STATEFUL_SET_NAME}" -o jsonpath='{.spec.replicas}')

    mkdir -p $(dirname "${TOPOLOGY_DESCRIPTOR_JSON}")
    # TODO: Consider using "jq" for more robust escaping of special characters.
    # TODO: Is it ok that the hostname is not really the hostname, but has "${ordinal}" in it?
    cat <<EOF > "${TOPOLOGY_DESCRIPTOR_JSON}"
{
    "${REGION}": {
        "hostname": "${LOCAL_HOSTNAME_TEMPLATE}",
        "replicas": ${NUM_REPLICAS}
    }
}
EOF
  else
    echo "185-offline-enable-wrapper.sh: Topology descriptor JSON \"${TOPOLOGY_DESCRIPTOR_JSON}\" already exists:"
  fi
  cat "${TOPOLOGY_DESCRIPTOR_JSON}"

  # For single region the hostnames are different, but the ports are the same.
  PD_PORT_INC=0
fi

# The basis for the LDAP(S) and replication port numbers to use.
PD_LDAP_PORT_BASE=$((PD_LDAP_PORT - PD_PORT_INC * ORDINAL))
PD_LDAPS_PORT_BASE=$((PD_LDAPS_PORT - PD_PORT_INC * ORDINAL))
REPL_PORT_BASE=$((PD_REPL_PORT - PD_PORT_INC * ORDINAL))

# Build a template for offline-enable.sh configuration.
# TODO: This could be a permanent file somewhere, but where?
offline_enable_template=$(mktemp -t "offline-enable-template-XXXXXXXXXX")
cat <<'EOF' > "${offline_enable_template}"
{
  "descriptor_json" : $descriptor_json,
  "inst_root"       : $inst_root,
  "local_region"    : $local_region,
  "local_ordinal"   : $local_ordinal,
  "inst_base"       : $inst_base,
  "inst_inc"        : $inst_inc,
  "repl_id_base"    : $repl_id_base,
  "repl_id_rinc"    : $repl_id_rinc,
  "repl_id_inc"     : $repl_id_inc,
  "ldap_port_base"  : $ldap_port_base,
  "ldap_port_inc"   : $ldap_port_inc,
  "ldaps_port_base" : $ldaps_port_base,
  "ldaps_port_inc"  : $ldaps_port_inc,
  "repl_port_base"  : $repl_port_base,
  "repl_port_inc"   : $repl_port_inc,
  "ads_truststore"  : $ads_truststore,
  "admin_user"      : $admin_user,
  "admin_pass_file" : $admin_pass_file
}
EOF

# TODO: This can probably be deleted.
echo "${offline_enable_template}:"
cat  "${offline_enable_template}"

# Build a configuration file for offline-enable.sh based on the above template.
# TODO: Consider replacing the "ads_truststore" with "none".
offline_enable_config=$(mktemp -t "offline-enable-config-XXXXXXXXXX")
jq -n --arg     descriptor_json "${TOPOLOGY_DESCRIPTOR_JSON}" \
      --arg     inst_root       "${SERVER_ROOT_DIR}"          \
      --arg     local_region    "${REGION}"                   \
      --argjson local_ordinal   "${ORDINAL}"                  \
      --argjson inst_base       "${PD_LDAPS_PORT_BASE}"       \
      --argjson inst_inc        "${PD_PORT_INC}"              \
      --argjson repl_id_base    1000                          \
      --argjson repl_id_rinc    1000                          \
      --argjson repl_id_inc     100                           \
      --argjson ldap_port_base  "${PD_LDAP_PORT_BASE}"        \
      --argjson ldap_port_inc   "${PD_PORT_INC}"              \
      --argjson ldaps_port_base "${PD_LDAPS_PORT_BASE}"       \
      --argjson ldaps_port_inc  "${PD_PORT_INC}"              \
      --argjson repl_port_base  "${PD_REPL_PORT_BASE}"        \
      --argjson repl_port_inc   "${PD_PORT_INC}"              \
      --arg     ads_truststore  "${SERVER_ROOT_DIR}"/config/ads-truststore \
      --arg     admin_user      "${ADMIN_USER_NAME}"          \
      --arg     admin_pass_file "${ADMIN_USER_PASSWORD_FILE}" \
      -f "${offline_enable_template}" > "${offline_enable_config}"

echo "${offline_enable_config}:"
cat  "${offline_enable_config}"

# Enable replication offline before the instances are started.
set -x
date
cp -f "${SERVER_ROOT_DIR}/config/config.ldif" "${SERVER_ROOT_DIR}/config/config.ldif.before"
"${HOOKS_DIR}"/185-offline-enable.sh -v "${offline_enable_config}" ${DNS_TO_INITIALIZE}
cp -f "${SERVER_ROOT_DIR}/config/config.ldif" "${SERVER_ROOT_DIR}/config/config.ldif.after"
date
set +x

# Remove temporary files.
rm -f "${offline_enable_template}" "${offline_enable_config}"
