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
# Generate a self-signed certificate for the provided domain. The subject of the certificate will match the domain name.
# A wildcard SAN (Subject Alternate Name) will be added as well. For example, for the domain foobar.com, the subject
# name will be "foobar.com" and the SAN "*.foobar.com". The PEM and base64 representation of the certificate and key
# will be exported in environment variables TLS_CRT_PEM, TLS_KEY_PEM, TLS_CRT_BASE64 and TLS_KEY_BASE64, respectively.
#
# Arguments
#   ${1} -> The name of the domain for which to generate the self-signed certificate.
#
########################################################################################################################
generate_tls_cert() {
  CERTS_DIR=$(mktemp -d)
  cd "${CERTS_DIR}"
  DOMAIN=${1}
  openssl req -x509 -nodes -newkey rsa:4096 -days 3650 -sha256 \
    -out tls.crt -keyout tls.key \
    -subj "/CN=${DOMAIN}" \
    -reqexts SAN -extensions SAN \
    -config <(cat /etc/ssl/openssl.cnf; printf "[SAN]\nsubjectAltName=DNS:*.${DOMAIN}") > /dev/null 2>&1
  export TLS_CRT_PEM=$(cat tls.crt)
  export TLS_KEY_PEM=$(cat tls.key)
  export TLS_CRT_BASE64=$(base64_no_newlines tls.crt)
  export TLS_KEY_BASE64=$(base64_no_newlines tls.key)
  cd - > /dev/null
  rm -rf "${CERTS_DIR}"
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
# Verify that the provided environment variables are set.
#
# Arguments
#   ${*} -> The list of required environment variables.
#
# Returns:
#   0 on success; non-zero otherwise.
########################################################################################################################
check_env_vars() {
  STATUS=0
  for NAME in ${*}; do
    VALUE="${!NAME}"
    if test -z "${VALUE}"; then
      echo "${NAME} environment variable must be set"
      STATUS=1
    fi
  done
  return ${STATUS}
}

########################################################################################################################
# Tests whether the provided URLs are reachable or not within a timeout of 2 minutes per URL. Refer to the "testUrl"
# function docs for more details.
#
# Arguments:
#   ${*} -> The list of URLs to test
#
# Returns:
#   0 on success; non-zero on curl failure
########################################################################################################################
testUrls() {
  local url status=0
  for url in ${*}; do
    ! testUrl "${url}" && status=1
  done
  return ${status}
}

########################################################################################################################
# Tests whether a URL is reachable or not within a timeout of 2 minutes.
#
# Arguments:
#   ${1} -> The URL
#   ${2} -> Flag indicating whether or not to verify that the HTTP status code is 2xx. Defaults to false. If true,
#           the username and password specified by environment variables ADMIN_USER and ADMIN_PASS are used for basic
#           authentication.
#   ${3} -> Flag indicating whether or not to use Basic Auth credentials when connecting.
#
# Returns:
#   0 on success; non-zero on curl failure or non-2xx HTTP code
########################################################################################################################
testUrl() {
  local url="${1}"
  local test_http_code="${2:-false}"
  local use_basic_auth=${3:-true}
  log "Testing URL: ${url} with basic auth set to ${use_basic_auth}"

  if [[ "${use_basic_auth}" = true ]];then
    http_code="$(curl -k --max-time "${CURL_TIMEOUT_SECONDS}" \
      -w '%{http_code}' "${url}" \
      -u "${ADMIN_USER}:${ADMIN_PASS}" \
      -H 'X-Xsrf-Header: PingAccess' \
      -o /dev/null 2>/dev/null)"
    exit_code=$?
  else
    http_code="$(curl -k --max-time "${CURL_TIMEOUT_SECONDS}" \
      -w '%{http_code}' "${url}" \
      -o /dev/null 2>/dev/null)"
    exit_code=$?
  fi

  log "Command exit code: ${exit_code}. HTTP return code: ${http_code}"
  test "${test_http_code}" = 'false' && return ${exit_code}

  test "${http_code%??}" -eq 2 &&
      return 0 ||
      return 1
}

########################################################################################################################
# Tests whether the provided URLs are reachable or not within a timeout of 2 minutes per URL. Non-2xx return codes are
# considered failures. Refer to the "testUrl" function docs for more details.
#
# Arguments:
#   ${*} -> The list of URLs to test
#
# Returns:
#   0 on success; non-zero on curl failure and non-2xx HTTP code
########################################################################################################################
testUrlsExpect2xx() {
  local url status=0
  for url in ${*}; do
    ! testUrl "${url}" true && status=1
  done
  return ${status}
}

testUrlsWithoutBasicAuthExpect2xx() {
  local url status=0
  for url in ${*}; do
    ! testUrl "${url}" true false && status=1
  done
  return ${status}
}
########################################################################################################################
# Tests whether a URL is reachable or not within a timeout of 2 minutes. Non-2xx return codes are considered failures.
# Refer to the "testUrl" function docs for more details.
#
# Arguments:
#   ${1} -> The URL
#
# Returns:
#   0 on success; non-zero on curl failure and non-2xx HTTP code
########################################################################################################################
testUrlExpect2xx() {
  local url="${1}"
  testUrl "${url}" true
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
# Build all kustomizations under the provided directory and its sub-directories.
#
# Arguments
#   ${1} -> The fully-qualified base directory.
#
# Returns:
#   0 on success; non-zero otherwise.
########################################################################################################################
build_kustomizations_in_dir() {
  DIR=${1}

  log "Building all kustomizations in directory ${DIR}"

  STATUS=0
  KUSTOMIZATION_FILES=$(find "${DIR}" -name kustomization.yaml)

  for KUSTOMIZATION_FILE in ${KUSTOMIZATION_FILES}; do
    KUSTOMIZATION_DIR=$(dirname ${KUSTOMIZATION_FILE})

    log "Processing kustomization.yaml in ${KUSTOMIZATION_DIR}"
    kustomize build --load_restrictor none "${KUSTOMIZATION_DIR}" 1> /dev/null
    BUILD_RESULT=${?}
    log "Build result for directory ${KUSTOMIZATION_DIR}: ${BUILD_RESULT}"

    test ${STATUS} -eq 0 && STATUS=${BUILD_RESULT}
  done

  log "Build result for base directory ${DIR}: ${STATUS}"

  return ${STATUS}
}

########################################################################################################################
# Builds all kustomizations in the generated code directory. Intended to only be used for building manifests generated by
# the generate-cluster-state.sh script.
#
# Arguments
#   ${1} -> The fully-qualified directory that contains the generated code.
#
# Returns:
#   0 on success; non-zero otherwise.
########################################################################################################################
build_generated_code() {
  DIR="$1"

  build_cluster_state_code "${DIR}"
  CLUSTER_STATE_BUILD_STATUS=$?

  build_bootstrap_code "${DIR}"
  BOOTSTRAP_BUILD_STATUS=$?

  if test ${CLUSTER_STATE_BUILD_STATUS} -eq 0 && test ${BOOTSTRAP_BUILD_STATUS} -eq 0; then
    return 0
  else
    return 1
  fi
}

########################################################################################################################
# Builds all kustomizations within the cluster-state directory of the generated code directory. Intended to only be
# used for building manifests generated by the generate-cluster-state.sh script.
#
# Arguments
#   ${1} -> The fully-qualified directory that contains the generated code.
#
# Returns:
#   0 on success; non-zero otherwise.
########################################################################################################################
build_cluster_state_code() {
  DIR="$1"

  STATUS=0
  log "Building cluster state code in directory ${DIR}"

  BASE_DIRS=$(find "${DIR}" -name base -type d)

  GIT_OPS_CMD_NAME='git-ops-command.sh'
  GIT_OPS_CMD="$(find "${DIR}" -name "${GIT_OPS_CMD_NAME}" -type f)"

  for BASE_DIR in ${BASE_DIRS}; do
    DIR_NAME="$(dirname "${BASE_DIR}")"
    CDE="$(basename "${DIR_NAME}")"
    REGION="$(ls "${DIR_NAME}" | grep -v 'base')"

    log "Processing manifests for region '${REGION}' and CDE '${CDE}'"
    cd "${BASE_DIR}"/..

    cp "${GIT_OPS_CMD}" .
    ./"${GIT_OPS_CMD_NAME}" "${REGION}" > /dev/null
    BUILD_RESULT=$?
    log "Build result for manifests for region '${REGION}' and CDE '${CDE}': ${BUILD_RESULT}"

    rm -f "${GIT_OPS_CMD_NAME}"
    cd - &>/dev/null

    test ${STATUS} -eq 0 && STATUS=${BUILD_RESULT}
  done

  log "Build result for cluster state code in directory ${DIR}: ${STATUS}"
  return ${STATUS}
}

########################################################################################################################
# Builds all kustomizations within the fluxcd directory of the generated code directory. Intended to only be
# used for building manifests generated by the generate-cluster-state.sh script.
#
# Arguments
#   ${1} -> The fully-qualified directory that contains the generated code.
#
# Returns:
#   0 on success; non-zero otherwise.
########################################################################################################################
build_bootstrap_code() {
  DIR="$1"

  STATUS=0
  log "Building bootstrap code in directory ${DIR}"

  BOOTSTRAP_DIR="${DIR}"/fluxcd
  CDE_DIRS="$(ls "${BOOTSTRAP_DIR}")"

  for CDE in ${CDE_DIRS}; do
    log "Building bootstrap code for CDE '${CDE}'"
    build_kustomizations_in_dir "${BOOTSTRAP_DIR}/${CDE}"
    BUILD_RESULT=$?
    log "Build result for bootstrap code for CDE '${CDE}': ${BUILD_RESULT}"

    test ${STATUS} -eq 0 && STATUS=${BUILD_RESULT}
  done

  log "Build result for bootstrap code in directory ${DIR}: ${STATUS}"
  return ${STATUS}
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
DEFAULT_VARS='${PING_IDENTITY_DEVOPS_USER_BASE64}
${PING_IDENTITY_DEVOPS_KEY_BASE64}
${ENVIRONMENT}
${BELUGA_ENV_NAME}
${IS_MULTI_CLUSTER}
${CLUSTER_BUCKET_NAME}
${EVENT_QUEUE_NAME}
${ORCH_API_SSM_PATH_PREFIX}
${REGION}
${REGION_NICK_NAME}
${PRIMARY_REGION}
${TENANT_DOMAIN}
${PRIMARY_TENANT_DOMAIN}
${GLOBAL_TENANT_DOMAIN}
${SECONDARY_TENANT_DOMAINS}
${CLUSTER_NAME}
${CLUSTER_NAME_LC}
${NAMESPACE}
${CONFIG_REPO_BRANCH}
${CONFIG_PARENT_DIR}
${TOPOLOGY_DESCRIPTOR}
${ARTIFACT_REPO_URL}
${PING_ARTIFACT_REPO_URL}
${LOG_ARCHIVE_URL}
${BACKUP_URL}
${NEW_RELIC_LICENSE_KEY_BASE64}
${TENANT_NAME}'

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
# Build the full Kubernetes yaml file for the dev and CI/CD environments.
#
# Arguments
#   $1 -> The output filename that will contain the full manifest when the function is done.
#   $2 -> Optional cluster type argument value of "secondary". Empty string implies primary cluster.
########################################################################################################################
build_dev_deploy_file() {
  local deploy_file=$1
  local cluster_type=$2

  local build_dir='build-dir'
  rm -rf "${build_dir}"

  local dev_cluster_state_dir='dev-cluster-state'
  cp -pr "${dev_cluster_state_dir}" "${build_dir}"

  substitute_vars "${build_dir}" "${DEFAULT_VARS}"
  kustomize build --load_restrictor none "${build_dir}/${cluster_type}" > "${deploy_file}"
  rm -rf "${build_dir}"

  test ! -z "${NAMESPACE}" && test "${NAMESPACE}" != 'ping-cloud' &&
      sed -i.bak -E "s/((namespace|name): )ping-cloud$/\1${NAMESPACE}/g" "${deploy_file}"
}
