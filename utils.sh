#!/bin/bash

########################################################################################################################
# Echoes a message prepended with the current time
#
# Arguments
#   ${1} -> The message to echo
########################################################################################################################
log() {
  LOG_FILE=${LOG_FILE:-/tmp/dev-env.log}
  echo "$(date) ${1}" | tee -a "${LOG_FILE}"
}

########################################################################################################################
# Generate an RSA key pair. The identity and the base64 representation of the key will exported in environment variables
# SSH_ID_PUB and SSH_ID_KEY_BASE64, respectively.
########################################################################################################################
generate_ssh_key_pair() {
  KEY_PAIR_DIR=$(mktemp -d)
  cd "${KEY_PAIR_DIR}"
  ssh-keygen -q -t rsa -b 2048 -f id_rsa -N ''
  export SSH_ID_PUB=$(cat id_rsa.pub)
  export SSH_ID_KEY_BASE64=$(base64_no_newlines id_rsa)
  cd - > /dev/null
  rm -rf "${KEY_PAIR_DIR}"
}

########################################################################################################################
# base64-encode the provided string or file contents and remove any new lines (both line feeds and carriage returns).
#
# Arguments
#   ${1} -> The string to base-64 encode, or a file whose contents to base64-encode.
########################################################################################################################
base64_no_newlines() {
  if test -f "${1}"; then
    cat "${1}" | base64 | tr -d '\r?\n'
  else
    echo -n "${1}" | base64 | tr -d '\r?\n'
  fi
}

########################################################################################################################
# Verify that the provided binaries are available.
#
# Arguments
#   ${*} -> The list of required binaries.
#
# Returns:
#   0 on success; non-zero otherwise.
########################################################################################################################
check_binaries() {
  STATUS=0
	for TOOL in ${*}; do
	  which "${TOOL}" &>/dev/null
    if test ${?} -ne 0; then
      echo "${TOOL} is required but missing"
      STATUS=1
    fi
  done
  return ${STATUS}
}

########################################################################################################################
# Parses the provided URL and exports its components into the environment variables URL_PROTOCOL, URL_USER, URL_PASS,
# URL_HOST, URL_PORT and URL_PART. All but the URL_HOST are optional. See example URLs below.
#
# Arguments
#   ${1} -> The URL from which to parse the host. Example URLs:
#             - git@github.com:savitha-ping/savitha-ping-stack.git
#             - https://github.com/savitha-ping/savitha-ping-stack.git
#             - ssh://APKAVPNHKJ3QM5XNXNWM@git-codecommit.ap-southeast-2.amazonaws.com/v1/repos/cluster-state-repo
#             - sftp://user@host.net/some/random/path
#             - sftp://user:password@host.net:1234/some/random/path
#   ${2} -> Debug mode. If true, prints the parsed values for protocol, username, password, host, port and path.
########################################################################################################################
parse_url() {
  URL="${1}"
  DEBUG="${2}"

  # Extract the protocol.
  if [[ "${URL}" =~ '://' ]]; then
    export URL_PROTOCOL=$(echo "${URL}" | sed -e 's|^\(.*://\).*|\1|g')
    URL_NO_PROTOCOL=$(echo "${URL}" | sed -e "s|${URL_PROTOCOL}||g")
  else
    export URL_PROTOCOL=
    URL_NO_PROTOCOL="${URL}"
  fi

  # Extract the user and password (if any).
  URL_USER_PASS=$(echo ${URL_NO_PROTOCOL} | grep @ | cut -d@ -f1)
  export URL_PASS=$(echo "${URL_USER_PASS}" | grep : | cut -d: -f2)
  if test -n "${URL_PASS}"; then
    export URL_USER=$(echo "${URL_USER_PASS}" | grep : | cut -d: -f1)
  else
    export URL_USER="${URL_USER_PASS}"
  fi

  # Extract the host.
  URL_HOST_PORT=$(echo "${URL_NO_PROTOCOL}" | sed -e "s|${URL_USER_PASS}@||g" | cut -d/ -f1)
  export URL_PORT=$(echo "${URL_HOST_PORT}" | grep : | cut -d: -f2)

  if test -n "${URL_PORT}"; then
    export URL_HOST=$(echo "${URL_HOST_PORT}" | grep : | cut -d: -f1)
  else
    export URL_HOST="${URL_HOST_PORT}"
  fi

  # Extract the path (if any).
  export URL_PATH=$(echo "${URL_NO_PROTOCOL}" | grep / | cut -d/ -f2-)

  if test "${DEBUG}" = 'true'; then
    echo "URL: ${URL}"
    echo "URL_PROTOCOL: ${URL_PROTOCOL}"

    echo "URL_USER: ${URL_USER}"
    echo "URL_PASS: ${URL_PASS}"

    echo "URL_HOST: ${URL_HOST}"
    echo "URL_PORT: ${URL_PORT}"

    echo "URL_PATH: ${URL_PATH}"
  fi
}

########################################################################################################################
# Substitute variables in all files in the provided directory.
#
# Arguments
#   $1 -> The directory that contains the files where variables must be substituted.
#   $2 -> The variables to be substituted. Check DEFAULT_VARS below for the expected format.
#   $3 -> Optional space-separated filenames to include for substitution. If not provided, environment variables in all
#         template files in the provided directory will be substituted.
########################################################################################################################

# The list of variables in the template files that will be substituted by default.
DEFAULT_VARS='${PING_IDENTITY_DEVOPS_USER}
${PING_IDENTITY_DEVOPS_KEY}
${ENVIRONMENT}
${BELUGA_ENV_NAME}
${IS_MULTI_CLUSTER}
${PLATFORM_EVENT_QUEUE_NAME}
${CUSTOMER_SSM_PATH_PREFIX}
${CUSTOMER_SSO_SSM_PATH_PREFIX}
${SERVICE_SSM_PATH_PREFIX}
${REGION}
${REGION_NICK_NAME}
${PRIMARY_REGION}
${TENANT_DOMAIN}
${PRIMARY_TENANT_DOMAIN}
${GLOBAL_TENANT_DOMAIN}
${SECONDARY_TENANT_DOMAINS}
${CLUSTER_NAME}
${CLUSTER_NAME_LC}
${PING_CLOUD_NAMESPACE}
${TOPOLOGY_DESCRIPTOR}
${ARTIFACT_REPO_URL}
${PING_ARTIFACT_REPO_URL}
${PD_MONITOR_BUCKET_URL}
${LOG_ARCHIVE_URL}
${BACKUP_URL}
${PGO_BACKUP_BUCKET_NAME}
${MYSQL_SERVICE_HOST}
${MYSQL_USER}
${MYSQL_PASSWORD}
${MYSQL_DATABASE}
${NEW_RELIC_LICENSE_KEY}
${NEW_RELIC_LICENSE_KEY_BASE64}
${TENANT_NAME}
${NEW_RELIC_ENVIRONMENT_NAME}
${DATASYNC_P1AS_SYNC_SERVER}
${PF_PROVISIONING_ENABLED}
${RADIUS_PROXY_ENABLED}
${EXTERNAL_INGRESS_ENABLED}
${DASH_REPO_URL}
${DASH_REPO_BRANCH}
${APP_RESYNC_SECONDS}'

substitute_vars() {
  local subst_dir="$1"
  local vars="$2"
  local included_filenames="${@:3}"

  for file in $(find "${subst_dir}" -type f); do
    include_file=true
    if test "${included_filenames}"; then
      include_file=false
      for included_filename in ${included_filenames}; do
        file_basename="$(basename "${file}")"
        if $(echo "${file_basename}" | grep -qi "^${included_filename}$"); then
          include_file=true
          break
        fi
      done
    fi
    "${include_file}" || continue

    local old_file="${file}.bak"
    cp "${file}" "${old_file}"
    envsubst "${vars}" < "${old_file}" > "${file}"
    rm -f "${old_file}"
  done
}

########################################################################################################################
# Retrieve and return SSM parameter or AWS Secrets value.
#
# Arguments
#   $1 -> SSM key path
#
#  Returns
#   0 on success; 1 if the aws ssm call fails or the key does not exist.
########################################################################################################################
get_ssm_value() {
  local ssm_key="$1"

  if ! ssm_value="$(aws ssm --region "${REGION}"  get-parameters \
    --names "${ssm_key%#*}" \
    --query 'Parameters[*].Value' \
    --with-decryption \
    --output text)"; then
      echo "$ssm_value"
      return 1
  fi

  if test -z "${ssm_value}"; then
    echo "Unable to find SSM path '${ssm_key%#*}'"
    return 1
  fi

  if [[ "$ssm_key" == *"secretsmanager"* ]]; then
    # grep for the value of the secrets manager object's key
    # the object's key is the string following the '#' in the ssm_key variable
    echo "${ssm_value}" | grep -Eo "${ssm_key#*#}[^,]*" | grep -Eo "[^:]*$"
  else
    echo "${ssm_value}"
  fi
}

########################################################################################################################
# Set a given variable name based on an SSM prefix and suffix. If SSM exists, the ssm_template will
# be used to set the value. If the SSM prefix is 'unused', no value is set and SSM isn't checked.
#
# Arguments
#   $1 -> var_name - the name of the variable to set
#   $2 -> var_default - the default value for the variable if SSM is unused or there is an error
#   $3 -> ssm_prefix - SSM prefix
#   $4 -> ssm_suffix - The rest of the SSM key past the prefix
#   $5 -> ssm_template - [OPTIONAL] A template to render with ${ssm_value} - for example -
#                        'Hello my name is ${ssm_value}' will set the variable $var_name to that rendered value
########################################################################################################################
set_var() {
  local var_name="${1}"
  local var_default="${2}"
  local ssm_prefix="${3}"
  local ssm_suffix="${4}"
  local ssm_template="${5}"

  # Set a default that will always be returned
  local var_value="${var_default}"

  # Get the actual variable value from the passed in var string
  if [[ "${!1}" != '' ]]; then
    var_value="${!1}"
    echo "${var_name} already set to '${var_value}'"
    return
  elif [[ ${ssm_prefix} != "unused" ]]; then
    # Remove ssm:/ if provided - all paths should start with '/'
    if [[ ${ssm_prefix} == *"ssm://"* ]]; then
      ssm_prefix="${ssm_prefix#ssm:/}"
    fi
    echo "${var_name} is not set, trying to find it in SSM..."
    if ! ssm_value=$(get_ssm_value "${ssm_prefix}${ssm_suffix}"); then
      printf '\tWARN: Issue fetching SSM path '%s%s' - %s...\nContinuing as this could be a disabled environment\n' \
             "${ssm_prefix}" "${ssm_suffix}" "${ssm_value}"
    else
      printf '\tFound "%s%s" in SSM\n' "${ssm_prefix}" "${ssm_suffix}"
      # Substitute ssm_value within the supplied ssm template, if template given
      if [ -n "${ssm_template}" ]; then
        var_value=$(echo "${ssm_template}" | ssm_value=${ssm_value} envsubst)
      else
        var_value="${ssm_value}"
      fi
    fi
  else
    printf "%s - not fetching SSM - prefix is set to 'unused'\n" "${var_name}"
  fi

  # Always export the variable and value
  printf '\tSetting "%s" to "%s"\n' "${var_name}" "${var_value}"
  export "${var_name}=${var_value}"
}