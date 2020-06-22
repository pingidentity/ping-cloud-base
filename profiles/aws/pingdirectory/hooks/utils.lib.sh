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

  # Check if endpoint is AWS cloud stroage service (S3 bucket)
  case "$BACKUP_URL" in "s3://"*)
    
    # Set AWS specific variable for skbn
    export AWS_REGION=${REGION}
    
    DIRECTORY_NAME=$(echo "${PING_PRODUCT}" | tr '[:upper:]' '[:lower:]')

    if ! $(echo "$BACKUP_URL" | grep -q "/$DIRECTORY_NAME"); then
      BACKUP_URL="${BACKUP_URL}/${DIRECTORY_NAME}"
    fi

  esac

  echo "Getting cluster metadata"
  METADATA=$(kubectl get "$(kubectl get pod -o name | grep "${HOSTNAME}")" \
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
# Replace the server's instance name, if multi-cluster. Instance name must be unique in the topology.
########################################################################################################################
function replace_instance_name() {
  if is_multi_cluster; then
    SHORT_HOST_NAME=$(hostname)
    ORDINAL=${SHORT_HOST_NAME##*-}

    INSTANCE_NAME="${PD_PUBLIC_HOSTNAME}-636${ORDINAL}"
    CONFIG_LDIF="${SERVER_ROOT_DIR}"/config/config.ldif

    echo "Replacing instance-name to ${INSTANCE_NAME}"

    # FIXME: use dsconfig to do this
    sed -i "s/^\(ds-cfg-instance-name: \).*$/\1${INSTANCE_NAME}/g" "${CONFIG_LDIF}"
    sed -i "s/^\(ds-cfg-server-instance-name: \).*$/\1${INSTANCE_NAME}/g" "${CONFIG_LDIF}"
  fi
}

########################################################################################################################
# Determines if the environment is running in the context of multiple clusters. If both PD_PARENT_PUBLIC_HOSTNAME and
# PD_PUBLIC_HOSTNAME, it is assumed to be multi-cluster.
#
# Returns
#   0 if multi-cluster; 1 if not.
########################################################################################################################
function is_multi_cluster() {
  test ! -z "${PD_PARENT_PUBLIC_HOSTNAME}" && test ! -z "${PD_PUBLIC_HOSTNAME}"
}