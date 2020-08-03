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
    export PD_LDAP_PORT="636${ORDINAL}"
  else
    MULTI_CLUSTER=false
    export PD_PUBLIC_HOSTNAME=$(hostname -f)
    export PD_LDAP_PORT="${LDAPS_PORT}"
  fi

  is_primary_cluster &&
    PRIMARY_CLUSTER=true ||
    PRIMARY_CLUSTER=false

  echo "MULTI_CLUSTER - ${MULTI_CLUSTER}"
  echo "PRIMARY_CLUSTER - ${PRIMARY_CLUSTER}"
  echo "LDAP_HOST_PORT - ${PD_PUBLIC_HOSTNAME}:${PD_LDAP_PORT}"
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