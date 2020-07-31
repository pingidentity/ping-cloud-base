#!/usr/bin/env sh

########################################################################################################################
# Makes a curl request to the PingFederate Admin API. The HTTP status code from the curl invocation will be
# stored in the HTTP_CODE variable.
#
# Arguments
#   $@ -> The URL and additional data needed to make the request.
########################################################################################################################
function make_api_request() {
  set +x
  HTTP_CODE=$(curl -k \
    --retry "${API_RETRY_LIMIT}" \
    --max-time "${API_TIMEOUT_WAIT}" \
    --retry-delay 1 \
    --retry-connrefused \
    -u "Administrator:${PF_ADMIN_USER_PASSWORD}" \
    -w '%{http_code}' \
    -H 'X-Xsrf-Header: PingFederate' "$@")
  RESULT=$?
  ${VERBOSE} && set -x

  echo "Admin API request status: ${RESULT}; HTTP status: ${HTTP_CODE}"
  return "${RESULT}"
}

########################################################################################################################
# Wait for the local PingFederate admin API to be up and running waiting 3 seconds between each check.
#
# Arguments
#   ${1} -> The optional endpoint to wait for. If not specified, the function will wait for the version endpoint.
########################################################################################################################
function wait_for_admin_api_endpoint() {
  TIMEOUT=3
  ENDPOINT="${1:-version}"
  API_REQUEST_URL="https://localhost:9999/pf-admin-api/v1/${ENDPOINT}"

  echo "Waiting for admin API endpoint at ${API_REQUEST_URL}"

  while true; do
    make_api_request -X GET "${API_REQUEST_URL}" -o /dev/null 2> /dev/null
    if test "${HTTP_CODE}" -eq 200; then
      echo "Admin API endpoint ${ENDPOINT} ready"
      return 0
    fi

    echo "Admin API not endpoint ${ENDPOINT} ready - will retry in ${TIMEOUT} seconds"
    sleep "${TIMEOUT}"
  done
}

#---------------------------------------------------------------------------------------------
# Function to obfuscate LDAP password
#---------------------------------------------------------------------------------------------

function obfuscatePassword() {
  currentDir="$(pwd)"
  cd "${SERVER_ROOT_DIR}/bin"

   #
   # Ensure Java home is set
   #
   if [ -z "${JAVA_HOME}" ]; then
      export JAVA_HOME=/usr/lib/jvm/default-jvm/jre/
   fi
   #
   # The master key may not exist, this means no key was passed in as a secret and this is the first run of PF
   # for this environment, we can use the obfuscate utility to generate a master key as a byproduct of obfuscating
   # the password used to authenticate to PingDirectory in the ldap properties file.
   #
   # Obfuscate the ldap password
   #
   export PF_LDAP_PASSWORD_OBFUSCATED=$(sh ./obfuscate.sh "${PF_LDAP_PASSWORD}" | tr -d '\n')
   #
   # Inject obfuscated password into ldap properties file. The password variable is protected with a ${_DOLLAR_}
   # prefix because the file is substituted twice the first pass sets the DN and resets the '$' on the password
   # variable so it's a legitimate candidate for substitution on this, the second pass.
   #
   mv ldap.properties ldap.properties.subst
   envsubst < ldap.properties.subst > ldap.properties
   rm ldap.properties.subst

   PF_LDAP_PASSWORD_OBFUSCATED="${PF_LDAP_PASSWORD_OBFUSCATED:8}"

   mv ../server/default/data/pingfederate-ldap-ds.xml ../server/default/data/pingfederate-ldap-ds.xml.subst
   envsubst < ../server/default/data/pingfederate-ldap-ds.xml.subst > ../server/default/data/pingfederate-ldap-ds.xml
   rm ../server/default/data/pingfederate-ldap-ds.xml.subst

   cd "${currentDir}"
}

########################################################################################################################
# Export values for PingFederate configuration settings based on single vs. multi cluster.
########################################################################################################################
function export_config_settings() {
  if is_multi_cluster; then
    MULTI_CLUSTER=true
    export PF_ADMIN_HOST_PORT="${PF_ADMIN_PUBLIC_HOSTNAME}"
  else
    MULTI_CLUSTER=false
    export PF_ADMIN_HOST_PORT="${PINGFEDERATE_ADMIN_SERVER}:${PF_ADMIN_PORT}"
  fi

  is_primary_cluster &&
    PRIMARY_CLUSTER=true ||
    PRIMARY_CLUSTER=false

  echo "MULTI_CLUSTER - ${MULTI_CLUSTER}"
  echo "PRIMARY_CLUSTER - ${PRIMARY_CLUSTER}"
  echo "PF_ADMIN_HOST_PORT - ${PF_ADMIN_HOST_PORT}"
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
# Set up the tcp.xml file based on whether it is a single-cluster or multi-cluster deployment.
########################################################################################################################
function configure_tcp_xml() {
  local currentDir="$(pwd)"
  cd "${SERVER_ROOT_DIR}/server/default/conf"

  if is_multi_cluster; then
    export TCP_PING="<TCPPING \
        initial_hosts=\"pingfederate-admin-0.pingfederate-cluster-savithaganapathi.${PRIMARY_TENANT_DOMAIN}[7600]\" \
        port_range=\"3\" />"
  else
    export DNS_PING="<dns.DNS_PING \
         dns_query=\"${PF_DNS_PING_CLUSTER}.${PF_DNS_PING_NAMESPACE}.svc.cluster.local\" />"
  fi

  mv tcp.xml tcp.xml.subst
  envsubst < tcp.xml.subst > tcp.xml
  rm -f tcp.xml.subst

  echo "configure_tcp_xml: contents of tcp.xml after substitution"
  cat tcp.xml

  cd "${currentDir}"
}

########################################################################################################################
# Set up tcp.xml based on whether it is a single-cluster or multi-cluster deployment.
########################################################################################################################
function configure_cluster() {
  configure_tcp_xml
}

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

  # Get prefix of HOSTNAME which match the pod name.
  POD="$(echo "${HOSTNAME}" | cut -d. -f1)"

  METADATA=$(kubectl get "$(kubectl get pod -o name | grep "${POD}")" \
    -o=jsonpath='{.metadata.namespace},{.metadata.name},{.metadata.labels.role}')

  METADATA_NS=$(echo "$METADATA"| cut -d',' -f1)
  METADATA_PN=$(echo "$METADATA"| cut -d',' -f2)
  METADATA_CN=$(echo "$METADATA"| cut -d',' -f3)

  # Remove suffix for PF runtime.
  METADATA_CN="${METADATA_CN%-engine}"

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
