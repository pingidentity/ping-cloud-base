#!/usr/bin/env sh

########################################################################################################################
# Function sets required environment variables for skbn
#
########################################################################################################################
function initializeSkbnConfiguration() {
  unset SKBN_CLOUD_PREFIX
  unset SKBN_K8S_PREFIX

  # Allow overriding the backup URL with an arg
  test ! -z "${1}" && BACKUP_URL="${1}"

  # Check if endpoint is AWS cloud storage service (S3 bucket)
  case "$BACKUP_URL" in "s3://"*)
    
    # Set AWS specific variable for skbn
    export AWS_REGION=${REGION}
    
    DIRECTORY_NAME=$(echo "${PING_PRODUCT}" | tr '[:upper:]' '[:lower:]')

    if ! $(echo "$BACKUP_URL" | grep -q "/$DIRECTORY_NAME"); then
      BACKUP_URL="${BACKUP_URL}/${DIRECTORY_NAME}"
    fi

  esac

  beluga_log "Getting cluster metadata"

  # Get prefix of HOSTNAME which match the pod name.
  export POD="$(echo "${HOSTNAME}" | cut -d. -f1)"

  METADATA=$(kubectl get "$(kubectl get pod -o name | grep "${POD}")" \
    -o=jsonpath='{.metadata.namespace},{.metadata.name},{.metadata.labels.role}')
    
  METADATA_NS=$(echo "${METADATA}"| cut -d',' -f1)
  METADATA_PN=$(echo "${METADATA}"| cut -d',' -f2)
  METADATA_CN=$(echo "${METADATA}"| cut -d',' -f3)

  export SKBN_CLOUD_PREFIX="${BACKUP_URL}"
  export SKBN_K8S_PREFIX="k8s://${METADATA_NS}/${METADATA_PN}/${METADATA_CN}"
}

########################################################################################################################
# Function to copy file(s) between cloud storage and k8s
#
########################################################################################################################
function skbnCopy() {
  PARALLEL="0"
  SOURCE="${1}"
  DESTINATION="${2}"

  # Check if the number of files to be copied in parallel is defined (0 for full parallelism)
  test ! -z "${3}" && PARALLEL="${3}"
  
  if ! skbn cp --src "$SOURCE" --dst "${DESTINATION}" --parallel "${PARALLEL}"; then
    return 1
  fi
}

########################################################################################################################
# Export values for PingDirectory configuration settings based on single vs. multi cluster.
########################################################################################################################
function export_config_settings() {
  if is_multi_cluster; then
    MULTI_CLUSTER=true
    SHORT_HOST_NAME=$(hostname)
    ORDINAL=${SHORT_HOST_NAME##*-}

    # If going over the NLB, we'd need to use distinct ports. But with VPC peering and
    # direct addressing, all PD servers can use the same LDAP and replication ports.
    export PD_LDAP_HOST="${K8S_STATEFUL_SET_NAME}-0.${PD_CLUSTER_PUBLIC_HOSTNAME}"

    # NLB settings:
    # export PD_LDAP_PORT="389${ORDINAL}"
    # export PD_LDAPS_PORT="636${ORDINAL}"
    # export PD_REPL_PORT="989${ORDINAL}"

    # VPC peer settings (same as single-region case):
    export PD_LDAP_PORT="${LDAP_PORT}"
    export PD_LDAPS_PORT="${LDAPS_PORT}"
    export PD_REPL_PORT="${REPLICATION_PORT}"
  else
    MULTI_CLUSTER=false
    export PD_LDAP_HOST="$(hostname -f)"

    export PD_LDAP_PORT="${LDAP_PORT}"
    export PD_LDAPS_PORT="${LDAPS_PORT}"
    export PD_REPL_PORT="${REPLICATION_PORT}"
  fi

  is_primary_cluster &&
    PRIMARY_CLUSTER=true ||
    PRIMARY_CLUSTER=false

  echo "MULTI_CLUSTER - ${MULTI_CLUSTER}"
  echo "PRIMARY_CLUSTER - ${PRIMARY_CLUSTER}"
  echo "PD_LDAP_HOST - ${PD_LDAP_HOST}"
  echo "LDAP_PORT - ${PD_LDAP_PORT}"
  echo "PD_LDAPS_PORT - ${PD_LDAPS_PORT}"
  echo "REPL_PORT - ${PD_REPL_PORT}"
}

########################################################################################################################
# Determines if the environment is running in the context of multiple clusters.
#
# Returns
#   true if multi-cluster; false if not.
########################################################################################################################
function is_multi_cluster() {
  test ! -z "${IS_MULTI_CLUSTER}" && "${IS_MULTI_CLUSTER}"
}

########################################################################################################################
# Determines if the environment is set up in the primary cluster.
#
# Returns
#   true if primary cluster; false if not.
########################################################################################################################
function is_primary_cluster() {
  test "${TENANT_DOMAIN}" = "${PRIMARY_TENANT_DOMAIN}"
}

########################################################################################################################
# Determines if the environment is set up in a secondary cluster.
#
# Returns
#   true if secondary cluster; false if not.
########################################################################################################################
function is_secondary_cluster() {
  ! is_primary_cluster
}

########################################################################################################################
# Standard log function.
#
########################################################################################################################
function beluga_log() {
  local format="+%Y-%m-%d:%Hh:%Mm:%Ss" # yyyy-mm-dd:00h:00m:00s
  local timestamp=$( date "${format}" )
  local message="${1}"
  local file_name=$(basename "${0}")

  echo "${timestamp} ${file_name}: ${message}"
}

########################################################################################################################
# Get LDIF for the base entry of USER_BASE_DN and return the LDIF file as stdout
########################################################################################################################
get_base_entry_ldif() {
  COMPUTED_DOMAIN=$(echo "${USER_BASE_DN}" | sed 's/^dc=\([^,]*\).*/\1/')
  COMPUTED_ORG=$(echo "${USER_BASE_DN}" | sed 's/^o=\([^,]*\).*/\1/')

  USER_BASE_ENTRY_LDIF=$(mktemp)

  if ! test "${USER_BASE_DN}" = "${COMPUTED_DOMAIN}"; then
    cat > "${USER_BASE_ENTRY_LDIF}" <<EOF
dn: ${USER_BASE_DN}
objectClass: top
objectClass: domain
dc: ${COMPUTED_DOMAIN}
EOF
  elif ! test "${USER_BASE_DN}" = "${COMPUTED_ORG}"; then
    cat > "${USER_BASE_ENTRY_LDIF}" <<EOF
dn: ${USER_BASE_DN}
objectClass: top
objectClass: organization
o: ${COMPUTED_DOMAIN}
EOF
  else
    echo "User base DN must be 1-level deep in one of these formats: dc=<domain>,dc=com or o=<org>,dc=com"
    return 80
  fi

  # Append some required ACIs to the base entry file. Without these, PF SSO will not work.
  cat >> "${USER_BASE_ENTRY_LDIF}" <<EOF
aci: (targetattr!="userPassword")(version 3.0; acl "Allow anonymous read access for anyone"; allow (read,search,compare) userdn="ldap:///anyone";)
aci: (targetattr!="userPassword")(version 3.0; acl "Allow self-read access to all user attributes except the password"; allow (read,search,compare) userdn="ldap:///self";)
aci: (targetattr="*")(version 3.0; acl "Allow users to update their own entries"; allow (write) userdn="ldap:///self";)
aci: (targetattr="*")(version 3.0; acl "Grant full access for the admin user"; allow (all) userdn="ldap:///uid=admin,${USER_BASE_DN}";)
EOF

  echo "${USER_BASE_ENTRY_LDIF}"
}

########################################################################################################################
# Add the base entry of USER_BASE_DN if it needs to be added
########################################################################################################################
add_base_entry_if_needed()
{
  REPL_INIT_MARKER_FILE="${SERVER_ROOT_DIR}"/config/repl-initialized

  if grep -q "${USER_BASE_DN}" "${REPL_INIT_MARKER_FILE}" &> /dev/null; then
    echo "Replication base DN ${DN} already added."
  else
    USER_BASE_ENTRY_LDIF=$(get_base_entry_ldif)
    echo "Adding replication base DN ${USER_BASE_DN} with contents:"
    cat "${USER_BASE_ENTRY_LDIF}"
    import-ldif -n userRoot -F -l "${USER_BASE_ENTRY_LDIF}"
  fi
}
