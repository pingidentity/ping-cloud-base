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
    set -x

    if test ! $? -eq 0; then
        echo "Admin API connection refused"
        stop_server
    fi

    if test ${http_code} -ne 200; then
        echo "API call returned HTTP status code: ${http_code}"
        cat ${OUT_DIR}/api_response.txt && rm -f ${OUT_DIR}/api_response.txt
        stop_server
    fi

    cat ${OUT_DIR}/api_response.txt && rm -f ${OUT_DIR}/api_response.txt
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
         -H "X-Xsrf-Header: PingAccess " "$@")
    set -x

    if test ! $? -eq 0; then
        echo "Admin API connection refused"
        stop_server
    fi

    if test ${http_code} -ne 200; then
        echo "API call returned HTTP status code: ${http_code}"
        cat ${OUT_DIR}/api_response.txt && rm -f ${OUT_DIR}/api_response.txt
        stop_server
    fi

    cat ${OUT_DIR}/api_response.txt && rm -f ${OUT_DIR}/api_response.txt
}

########################################################################################################################
# Used for API calls that specify an output file.
# When using this function the existence of the output file
# should be used to verify this function succeeded.
#
########################################################################################################################
function make_api_request_download() {
    set +x
    curl -k \
         --retry ${API_RETRY_LIMIT} \
         --max-time ${API_TIMEOUT_WAIT} \
         --retry-delay 1 \
         --retry-connrefused \
         -u ${PA_ADMIN_USER_USERNAME}:${PA_ADMIN_USER_PASSWORD} \
         -H "X-Xsrf-Header: PingAccess " "$@"
    set -x

    if test ! $? -eq 0; then
        echo "Admin API connection refused"
        stop_server
    fi
}

########################################################################################################################
# Makes curl request to localhost PingAccess admin Console heartbeat page.
# If request fails, wait for 3 seconds and try again.
#
########################################################################################################################
function pingaccess_admin_wait() {
    while true; do
        curl -ss --silent -o /dev/null -k https://localhost:9000/pa/heartbeat.ping 
        if ! test $? -eq 0; then
            echo "Import Config: Server not started, waiting.."
            sleep 3
        else
            echo "PA started, begin import"
            break
        fi
    done
}

########################################################################################################################
# Function to install AWS command line tools
#
########################################################################################################################
function installAwsCliTools() {
  if test -z "$(which aws)"; then
    #   
    #  Install AWS platform specific tools
    #
    echo "Installing AWS CLI tools for S3 support"
    #
    # TODO: apk needs to move to the Docker file as the package manager is plaform specific
    #
    apk --update add python3
    pip3 install --no-cache-dir --upgrade pip
    pip3 install --no-cache-dir --upgrade awscli
  fi
}

########################################################################################################################
# Function calls installAwsCliTools() and sets required environment variables for AWS S3 bucket
#
########################################################################################################################
function initializeS3Configuration() {
  unset BUCKET_URL_NO_PROTOCOL
  unset BUCKET_NAME
  unset DIRECTORY_NAME
  unset TARGET_URL

  # Allow overriding the backup URL with an arg
  test ! -z "${1}" && BACKUP_URL="${1}"

  # Install AWS CLI if the upload location is S3
  if test "${BACKUP_URL#s3}" == "${BACKUP_URL}"; then
    echo "Upload location is not S3"
    exit 1
  else
    installAwsCliTools
  fi

  export BUCKET_URL_NO_PROTOCOL=${BACKUP_URL#s3://}
  export BUCKET_NAME=$(echo "${BUCKET_URL_NO_PROTOCOL}" | cut -d/ -f1)
  export DIRECTORY_NAME=$(echo "${PING_PRODUCT}" | tr '[:upper:]' '[:lower:]')

  if test "${BACKUP_URL}" == */"${DIRECTORY_NAME}"; then
    export TARGET_URL="${BACKUP_URL}"
  else
    export TARGET_URL="${BACKUP_URL}/${DIRECTORY_NAME}"
  fi
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
  set -x

  if test ${isPasswordEmpty} -eq 1; then
    echo "The old and new passwords cannot be blank"
    stop_server
  elif test ${isPasswordSame} -eq 1; then
    echo "old passsword and new password are the same, therefore cannot update passsword"
    stop_server
  else
    # Change the default password.
    # Using set +x to suppress shell debugging
    # because it reveals the new admin password
    set +x
    change_password_payload=$(envsubst < ${STAGING_DIR}/templates/81/change_password.json)
    make_initial_api_request -s -X PUT \
        -d "${change_password_payload}" \
        "https://localhost:9000/pa-admin-api/v3/users/1/password" > /dev/null
    set -x
    CHANGE_PASWORD_STATUS=${?}

    echo "password change status: ${CHANGE_PASWORD_STATUS}"

    # If no error, write password to disk
    if test ${CHANGE_PASWORD_STATUS} -eq 0; then
      createSecretFile
      return 0
    fi

    echo "error changing password"
    stop_server
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
  set -x
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
  set -x
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
  set -x
}