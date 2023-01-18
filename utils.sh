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
# Format the provided kustomize version for numeric comparison. For example, if the kustomize version is 4.0.5, it
# returns 004000005000.
#
# Arguments
#   ${1} -> The kustomize short version, e.g. v4.0.5.
########################################################################################################################
format_version() {
  version="$1"
  printf "%03d%03d%03d%03d" $(echo "${version}" | tr '.' ' ')
}

########################################################################################################################
# Returns the version of kustomize formatted for numeric comparison. For example, if the kustomize version is 4.0.5,
# it returns 004000005000.
########################################################################################################################
kustomize_version() {
  version="$(kustomize version --short | grep -oE '[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+')"
  format_version "${version}"
}

########################################################################################################################
# Sets the "kustomize" load restriction build arg and value in the variables 'build_load_arg' and 'build_load_arg_value'
# if they are not already set to allow loading patch files that are not directly under the kustomize base depending on
# the version of kustomize.
########################################################################################################################
set_kustomize_load_arg_and_value() {
  if test "${build_load_arg}" && test "${build_load_arg_value}"; then
    return
  fi

  KUST_VER="$(kustomize_version)"
  log "Detected kustomize version ${KUST_VER}"

  # The load restriction build arg name and value are different starting in kustomize v4.0.1. This argument allows
  # kustomize to load patch files that are not directly under the kustomize base. For example, we need this option for
  # the remove-from-secondary-patch.yaml because it lives in base and is outside of the kustomize root of the region
  # directories.
  VER_4_0_1="$(format_version '4.0.1')"

  if test ${KUST_VER} -ge ${VER_4_0_1}; then
    build_load_arg='--load-restrictor'
    build_load_arg_value='LoadRestrictionsNone'
  else
    build_load_arg='--load_restrictor'
    build_load_arg_value='none'
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

    if grep "kind: Component" ${KUSTOMIZATION_FILE}
    then
      log "${KUSTOMIZATION_DIR} is a Component. Skipping"
      continue
    fi

    log "Processing kustomization.yaml in ${KUSTOMIZATION_DIR}"
    set_kustomize_load_arg_and_value
    kustomize build "${build_load_arg}" "${build_load_arg_value}" "${KUSTOMIZATION_DIR}" 1> /dev/null
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

  BASE_DIRS=$(find "${DIR}/cluster-state/k8s-configs" -name base -type d -maxdepth 2)

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
DEFAULT_VARS='${PING_IDENTITY_DEVOPS_USER}
${PING_IDENTITY_DEVOPS_KEY}
${ENVIRONMENT}
${BELUGA_ENV_NAME}
${IS_MULTI_CLUSTER}
${PLATFORM_EVENT_QUEUE_NAME}
${ORCH_API_SSM_PATH_PREFIX}
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
${CONFIG_REPO_BRANCH}
${CONFIG_PARENT_DIR}
${TOPOLOGY_DESCRIPTOR}
${ARTIFACT_REPO_URL}
${PING_ARTIFACT_REPO_URL}
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
${LEGACY_LOGGING}
${PF_PROVISIONING_ENABLED}
${RADIUS_PROXY_ENABLED}
${DASH_REPO_URL}
${DASH_REPO_BRANCH}'

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

  pgo_dev_deploy "${build_dir}"

  substitute_vars "${build_dir}" "${DEFAULT_VARS}"
  set_kustomize_load_arg_and_value
  kustomize build "${build_load_arg}" "${build_load_arg_value}" "${build_dir}/${cluster_type}" > "${deploy_file}"

  if [[ "${DEBUG}" != "true" ]]; then
    rm -rf "${build_dir}"
  fi

  test ! -z "${PING_CLOUD_NAMESPACE}" && test "${PING_CLOUD_NAMESPACE}" != 'ping-cloud' &&
      sed -i.bak -E "s/((namespace|name): )ping-cloud$/\1${PING_CLOUD_NAMESPACE}/g" "${deploy_file}"
}

########################################################################################################################
# Build the full Kubernetes yaml files for the dev and CI/CD environments into the provided directory.
#
# Arguments
#   $1 -> The output directory name that will contain the full manifest files when the function is done.
#   $2 -> Optional cluster type argument value of "secondary". Empty string implies primary cluster.
########################################################################################################################
build_dev_deploy_dir() {
  local deploy_dir="$1"
  local cluster_type="$2"

  local build_dir='build-dir'
  rm -rf "${build_dir}"

  local dev_cluster_state_dir='dev-cluster-state'
  cp -pr "${dev_cluster_state_dir}" "${build_dir}"

  substitute_vars "${build_dir}" "${DEFAULT_VARS}"
  set_kustomize_load_arg_and_value
  kustomize build "${build_load_arg}" "${build_load_arg_value}" "${build_dir}/${cluster_type}" --output "${deploy_dir}"
  rm -rf "${build_dir}"

  test ! -z "${PING_CLOUD_NAMESPACE}" && test "${PING_CLOUD_NAMESPACE}" != 'ping-cloud' &&
      find "${deploy_dir}" -type f -exec sed -i.bak -E "s/((namespace|name): )ping-cloud$/\1${PING_CLOUD_NAMESPACE}/g" {} \;
  rm -f "${deploy_dir}"/*.bak
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

# Deploy PGO - only if the feature flag is enabled!
# Arg $1 - directory containing pgo CRDs
pgo_dev_deploy() {
  local build_dir=${1}

  kust_file="${build_dir}/cluster-tools/pgo/kustomization.yaml"
  prov_kust_file="${build_dir}/ping-cloud/pingfederate/provisioning/kustomization.yaml"
  monitor_kust_file="${build_dir}/cluster-tools/monitoring/pgo/kustomization.yaml"
  pgo_feature_flag "${kust_file}" "${prov_kust_file}" "${monitor_kust_file}"
}

# Clear the kustomize file, effectively turning off that block of kustomize code
pgo_feature_flag() {
  local pgo_kust_file="${1}"
  local prov_kust_file="${2}"
  local monitor_kust_file="${3}"

  if [[ $PF_PROVISIONING_ENABLED != "true" ]]; then
    log "FEATURE FLAG - PF Provisioning is disabled, removing"
    message="# PF_PROVISIONING_ENABLED has been set to 'false', therefore this file has been cleared to disable the feature"
    component_message="kind: Component
apiVersion: kustomize.config.k8s.io/v1alpha1
# PF_PROVISIONING_ENABLED has been set to 'false', therefore this file has been cleared to disable the feature"
    echo "${message}" > "${pgo_kust_file}"
    echo "${message}" > "${prov_kust_file}"
    echo "${component_message}" > "${monitor_kust_file}"
  fi
}

########################################################################################################################
# Gets rollout status and waits to return until either the timeout is reached or the rollout is ready
#
# Arguments
#   $1 -> resource to check rollout status
#   $2 -> namespace for resource
#   $3 -> timeout for check
########################################################################################################################
wait_for_rollout() {
  local resource="${1}"
  local namespace="${2}"
  local timeout="${3}"
  time kubectl rollout status "${resource}" --timeout "${timeout}s" -n "${namespace}" -w
}

########################################################################################################################
# Apply CRD yaml and wait until cluster reports CRD established
#
# Arguments
#   $1 -> CRD yaml file - *** must only contain CRDs *** otherwise will hang waiting for other objects to be "established"
#   $2 -> timeout for waiting for CRD to be established
########################################################################################################################
apply_crd() {
  local crd_yaml=${1}
  local timeout=${2}

  kubectl apply -f "${crd_yaml}"
  kubectl wait --for condition="established" --timeout="${timeout}s" -f "${crd_yaml}"
}

########################################################################################################################
# Apply Custom Resource Definitions
#
# Add any CRDs that need to be set up before deploying custom objects to this function
#
# Arguments
#   $1 -> base directory where k8s-configs dir exists
########################################################################################################################
apply_crds() {
  local base_dir=${1}
  local timeout="60"

  # First, we need to deploy cert-manager. This is due to it using Dynamic Admission Control - Mutating Webhooks which
  # must be available before we make use cert-manager
  kubectl apply -f "${base_dir}/k8s-configs/cluster-tools/base/cert-manager/base/cert-manager.yaml"

  # Set namespace to cert-manager - somehow cmctl is not able to automatically use the correct namespace
  # Might be related to https://stackoverflow.com/questions/56980287/namespaces-not-found
  cmctl check api --wait=2m -n cert-manager

  # argo-events CRDs
  argo_crd_yaml="${base_dir}/k8s-configs/cluster-tools/base/notification/argo-events/argo-events-crd.yaml"
  apply_crd "${argo_crd_yaml}" "${timeout}"

  if [[ $PF_PROVISIONING_ENABLED == "true" ]]; then
    pgo_crd_dir="${base_dir}/k8s-configs/cluster-tools/base/pgo/base/crd/"
    log "FEATURE FLAG - PF Provisioning is enabled, deploying PGO CRD"
    # PGO CRDs are so large, they have to be applied server-side
    kubectl apply --server-side -k "${pgo_crd_dir}"
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
