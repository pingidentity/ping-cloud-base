#!/usr/bin/env sh

########################################################################################################################
# Makes curl request to PingAccess API using the INITIAL_ADMIN_PASSWORD environment variable.
#
########################################################################################################################
function make_api_request() {
    curl -k \
         --retry ${API_RETRY_LIMIT} \
         --max-time ${API_TIMEOUT_WAIT} \
         --retry-delay 1 \
         --retry-connrefused \
         -u ${PA_ADMIN_USER_USERNAME}:${PA_ADMIN_USER_PASSWORD} \
         -H "X-Xsrf-Header: PingAccess " "$@"

    if test ! $? -eq 0; then
        echo "Admin API connection refused"
        exit 1
    fi
}

########################################################################################################################
# Makes curl request to PingAccess API using the '2Access' password.
#
########################################################################################################################
function make_initial_api_request() {
    curl -k \
         --retry ${API_RETRY_LIMIT} \
         --max-time ${API_TIMEOUT_WAIT} \
         --retry-delay 1 \
         --retry-connrefused \
         -u ${PA_ADMIN_USER_USERNAME}:${DEFAULT_PA_ADMIN_USER_PASSWORD} \
         -H "X-Xsrf-Header: PingAccess " "$@"

    if test ! $? -eq 0; then
        echo "Admin API connection refused"
        exit 1
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