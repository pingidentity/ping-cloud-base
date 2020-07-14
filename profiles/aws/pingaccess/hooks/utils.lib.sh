#!/usr/bin/env sh

########################################################################################################################
# Stop PingAccess server and wait until it is terminated.
#
########################################################################################################################
function stop_server()
{
  SERVER_PID=$(pgrep -alf java | grep 'run.properties' | awk '{ print $1; }')
  kill "${SERVER_PID}"
  while true; do
    SERVER_PID=$(pgrep -alf java | grep 'run.properties' | awk '{ print $1; }')
    if test -z ${SERVER_PID}; then
        break
    else
      echo "waiting for PingAccess to terminate due to error"
      sleep 3
    fi
  done
  exit 1
}

########################################################################################################################
# Makes curl request to PingAccess API using the INITIAL_ADMIN_PASSWORD environment variable.
#
########################################################################################################################
function make_api_request() {
    set +x
    http_code=$(curl -k -o ${OUT_DIR}/api_response.txt -w "%{http_code}" \
         --retry ${API_RETRY_LIMIT} \
         --max-time ${API_TIMEOUT_WAIT} \
         --retry-delay 1 \
         --retry-connrefused \
         -u ${PA_ADMIN_USER_USERNAME}:${PA_ADMIN_USER_PASSWORD} \
         -H "X-Xsrf-Header: PingAccess " "$@")
    curl_result=$?
    "${VERBOSE}" && set -x

    if test "${curl_result}" -ne 0; then
        echo "Admin API connection refused"
        "${STOP_SERVER_ON_FAILURE}" && stop_server || exit 1
    fi

    if test "${http_code}" -ne 200; then
        echo "API call returned HTTP status code: ${http_code}"
        "${STOP_SERVER_ON_FAILURE}" && stop_server || exit 1
    fi

    cat ${OUT_DIR}/api_response.txt && rm -f ${OUT_DIR}/api_response.txt

    return 0
}

########################################################################################################################
# Makes curl request to PingAccess API using the '2Access' password.
#
########################################################################################################################
function make_initial_api_request() {
    set +x
    http_code=$(curl -k -o ${OUT_DIR}/api_response.txt -w "%{http_code}" \
         --retry ${API_RETRY_LIMIT} \
         --max-time ${API_TIMEOUT_WAIT} \
         --retry-delay 1 \
         --retry-connrefused \
         -u ${PA_ADMIN_USER_USERNAME}:${OLD_PA_ADMIN_USER_PASSWORD} \
         -H 'X-Xsrf-Header: PingAccess' "$@")
    curl_result=$?
    "${VERBOSE}" && set -x

    if test "${curl_result}" -ne 0; then
        echo "Admin API connection refused"
        "${STOP_SERVER_ON_FAILURE}" && stop_server || exit 1
    fi

    if test "${http_code}" -ne 200; then
        echo "API call returned HTTP status code: ${http_code}"
        "${STOP_SERVER_ON_FAILURE}" && stop_server || exit 1
    fi

    cat ${OUT_DIR}/api_response.txt && rm -f ${OUT_DIR}/api_response.txt

    return 0
}

########################################################################################################################
# Used for API calls that specify an output file.
# When using this function the existence of the output file
# should be used to verify this function succeeded.
#
########################################################################################################################
function make_api_request_download() {
    set +x
    http_code=$(curl -k -w "%{http_code}" \
         --retry ${API_RETRY_LIMIT} \
         --max-time ${API_TIMEOUT_WAIT} \
         --retry-delay 1 \
         --retry-connrefused \
         -u ${PA_ADMIN_USER_USERNAME}:${PA_ADMIN_USER_PASSWORD} \
         -H "X-Xsrf-Header: PingAccess " "$@")
    curl_result=$?
    "${VERBOSE}" && set -x

    if test "${curl_result}" -ne 0; then
        echo "Admin API connection refused"
        "${STOP_SERVER_ON_FAILURE}" && stop_server || exit 1
    fi

    if test "${http_code}" -ne 200; then
        echo "API call returned HTTP status code: ${http_code}"
        "${STOP_SERVER_ON_FAILURE}" && stop_server || exit 1
    fi

    return 0
}

########################################################################################################################
# Makes curl request to localhost PingAccess admin Console heartbeat page.
# If request fails, wait for 3 seconds and try again.
#
# Arguments
#   ${1} -> Optional host:port. Defaults to localhost:9000
########################################################################################################################
function pingaccess_admin_wait() {
    HOST_PORT="${1:-localhost:9000}"
    echo "Waiting for admin server at ${HOST_PORT}"
    while true; do
        curl -ss --silent -o /dev/null -k https://"${HOST_PORT}"/pa/heartbeat.ping
        if ! test $? -eq 0; then
            echo "Admin server not started, waiting.."
            sleep 3
        else
            echo "Admin server started"
            break
        fi
    done
}

# A function to help with unit
# test mocking.  Please do not
# delete!
function inject_template() {
  echo $(envsubst < ${1})
  return $?;
}

########################################################################################################################
# Function to change password.
#
########################################################################################################################
function changePassword() {

  # Validate before attempting to change password
  set +x
  if test -z "${OLD_PA_ADMIN_USER_PASSWORD}" || test -z "${PA_ADMIN_USER_PASSWORD}"; then
    isPasswordEmpty=1
  else
    isPasswordEmpty=0
  fi
  if test "${OLD_PA_ADMIN_USER_PASSWORD}" = "${PA_ADMIN_USER_PASSWORD}"; then
    isPasswordSame=1
  else
    isPasswordSame=0
  fi
  "${VERBOSE}" && set -x

  if test ${isPasswordEmpty} -eq 1; then
    echo "The old and new passwords cannot be blank"
    "${STOP_SERVER_ON_FAILURE}" && stop_server || exit 1
  elif test ${isPasswordSame} -eq 1; then
    echo "old password and new password are the same, therefore cannot update password"
    "${STOP_SERVER_ON_FAILURE}" && stop_server || exit 1
  else
    # Change the default password.
    # Using set +x to suppress shell debugging
    # because it reveals the new admin password
    set +x
    change_password_payload=$(inject_template ${STAGING_DIR}/templates/81/change_password.json)
    make_initial_api_request -s -X PUT \
        -d "${change_password_payload}" \
        "https://localhost:9000/pa-admin-api/v3/users/1/password" > /dev/null
    CHANGE_PASSWORD_STATUS=${?}
    "${VERBOSE}" && set -x

    echo "password change status: ${CHANGE_PASSWORD_STATUS}"

    # If no error, write password to disk
    if test ${CHANGE_PASSWORD_STATUS} -eq 0; then
      createSecretFile
      return 0
    fi

    echo "error changing password"
    "${STOP_SERVER_ON_FAILURE}" && stop_server || exit 1
  fi
}

########################################################################################################################
# Function to read password within ${OUT_DIR}/secrets/pa-admin-password.
#
########################################################################################################################
function readPasswordFromDisk() {
  set +x
  # if file doesn't exist return empty string
  if ! test -f ${OUT_DIR}/secrets/pa-admin-password; then
    echo ""
  else
    password=$( cat ${OUT_DIR}/secrets/pa-admin-password )
    echo ${password}
  fi
  "${VERBOSE}" && set -x
  return 0
}

########################################################################################################################
# Function to write admin password to disk.
#
########################################################################################################################
function createSecretFile() {
  # make directory if it doesn't exist
  mkdir -p ${OUT_DIR}/secrets
  set +x
  echo "${PA_ADMIN_USER_PASSWORD}" > ${OUT_DIR}/secrets/pa-admin-password
  "${VERBOSE}" && set -x
  return 0
}

########################################################################################################################
# Compare passwoord disk secret and desired value (environoment variable).
# Print 0 if passwords dont match, print 1 if they are the same.
#
########################################################################################################################
function comparePasswordDiskWithVariable() {
  set +x
  # if from disk is different than the desired value return false
  if ! test "$(readPasswordFromDisk)" = "${PA_ADMIN_USER_PASSWORD}"; then
    echo 0
  else
    echo 1
  fi
  "${VERBOSE}" && set -x
  return 0
}

#########################################################################################################################
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

  # Remove suffix for runtime.
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


########################################################################################################################
# Determines if the environment is running in the context of multiple clusters. If both PA_ADMIN_PUBLIC_HOSTNAME and
# PA_ENGINE_PUBLIC_HOSTNAME, it is assumed to be multi-cluster.
#
# Returns
#   0 if multi-cluster; 1 if not.
########################################################################################################################
function is_multi_cluster() {
  test ! -z "${PA_ADMIN_PUBLIC_HOSTNAME}" && test ! -z "${PA_ENGINE_PUBLIC_HOSTNAME}"
}

########################################################################################################################
# Export the values for the CLUSTER_CONFIG_HOST and CLUSTER_CONFIG_PORT environment variables to be used for
# substitution in JSON payloads to the admin API based on single vs. multi cluster.
########################################################################################################################
function export_cluster_config_host_port() {
  if is_multi_cluster; then
    export CLUSTER_CONFIG_HOST="${PA_CLUSTER_PUBLIC_HOSTNAME}"
    export CLUSTER_CONFIG_PORT=443
  else
    export CLUSTER_CONFIG_HOST="${K8S_SERVICE_NAME_PINGACCESS_ADMIN}"
    export CLUSTER_CONFIG_PORT=9090
  fi
}

########################################################################################################################
# Update the PA admin's host:port to be set in every engine's bootstrap.properties file.
########################################################################################################################
function update_admin_config_host_port() {
  local templates_dir_path="${STAGING_DIR}/templates/81"

  # Substitute the right values into the admin-config.json file based on single or multi cluster.
  export_cluster_config_host_port
  admin_config_payload=$(envsubst < "${templates_dir_path}"/admin-config.json)

  admin_config_response=$(make_api_request -s -X PUT \
      -d "${admin_config_payload}" \
      "https://localhost:9000/pa-admin-api/v3/adminConfig")
}

########################################################################################################################
# Determines if the environment is running in the context of multiple clusters. If both PA_ADMIN_PUBLIC_HOSTNAME and
# PA_ENGINE_PUBLIC_HOSTNAME, it is assumed to be multi-cluster.
#
# Returns
#   0 if multi-cluster; 1 if not.
########################################################################################################################
function is_multi_cluster() {
  if test ! -z "${PA_ADMIN_PUBLIC_HOSTNAME}" && test ! -z "${PA_ENGINE_PUBLIC_HOSTNAME}"; then
    echo true
  else
    echo false
  fi
}

########################################################################################################################
# Determines if the environment is secondary cluster.
#
# Returns
#   true if sub-cluster; false if not.
########################################################################################################################
function is_sub_cluster() {
  is_multi_cluster=$(is_multi_cluster)
  if [ "${is_multi_cluster}" = "true" ]; then
    ADMIN_TENANT_DOMAIN=$(echo "$PA_ADMIN_PUBLIC_HOSTNAME" | cut -d. -f2- )
    ENGINE_TENANT_DOMAIN=$(echo "$PA_ENGINE_PUBLIC_HOSTNAME" | cut -d. -f2- )
    if [ "$ADMIN_TENANT_DOMAIN" != "$ENGINE_TENANT_DOMAIN" ]; then
      echo true
      return 0
    fi
  fi

  echo false
}
