#!/bin/bash

##################################################################
# Common variables
##################################################################

test "${VERBOSE}" && set -x

# Source some utility methods.
export PROJECT_DIR="${CI_PROJECT_DIR}"
. ${PROJECT_DIR}/utils.sh

# Override environment variables with optional file supplied from the outside
ENV_VARS_FILE="${1}"

# Integration tests to skip.  Unit tests cannot be skipped.
SKIP_TESTS="${SKIP_TESTS:-pingdirectory/03-backup-restore.sh \
  pingfederate/02-csd-upload-test.sh \
  pingaccess-was/09-csd-upload-test.sh \
  pingaccess/11-heartbeat-endpoint.sh \
  pingaccess/09-csd-upload-test.sh \
  pingaccess/03-change-default-db-password-test.sh \
  pingfederate/09-heartbeat-endpoint.sh \
  pingaccess/08-artifact-test.sh \
  pingdelegator/01-admin-user-login.sh \
  chaos/01-delete-pa-admin-pod.sh }"

# environment variables that are determined based on deployment type (traditional or PingOne)
set_deploy_type_env_vars() {
  # MySQL database names cannot have dashes. So transform dashes into underscores.
  ENV_NAME_NO_DASHES=$(echo ${CI_COMMIT_REF_SLUG} | tr '-' '_')

  if [[ -n ${PINGONE} ]]; then
    # Set PingOne deploy env vars
    echo "Setting env vars for PingOne deployment"
    export PING_CLOUD_NAMESPACE=ping-p1-${CI_COMMIT_REF_SLUG}
    export PLATFORM_EVENT_QUEUE_NAME="${SELECTED_KUBE_NAME}_v2_platform_event_queue.fifo"
    export ORCH_API_SSM_PATH_PREFIX="/${SELECTED_KUBE_NAME}/pcpt/orch-api"
    export MYSQL_DATABASE="p1_pingcentral${ENV_NAME_NO_DASHES}"
    export BELUGA_ENV_NAME=p1-${CI_COMMIT_REF_SLUG}
    if [[ ${CI_COMMIT_REF_SLUG} != master ]]; then
      export ENVIRONMENT=-p1-${CI_COMMIT_REF_SLUG}
    fi
  else
    # Set traditional deploy env vars
    echo "Setting env vars for traditional deployment"
    export PING_CLOUD_NAMESPACE=ping-cloud-${CI_COMMIT_REF_SLUG}
    export PLATFORM_EVENT_QUEUE_NAME="v2_platform_event_queue.fifo"
    export ORCH_API_SSM_PATH_PREFIX="/pcpt/orch-api"
    export MYSQL_DATABASE="pingcentral_${ENV_NAME_NO_DASHES}"
    export BELUGA_ENV_NAME=${CI_COMMIT_REF_SLUG}
    if [[ ${CI_COMMIT_REF_SLUG} != master ]]; then
      export ENVIRONMENT=-${CI_COMMIT_REF_SLUG}
    fi
  fi
}

# all other environment variables
set_env_vars() {
  if test -z "${ENV_VARS_FILE}"; then
    echo "Using environment variables based on CI variables"

    export CLUSTER_NAME="${SELECTED_KUBE_NAME:-ci-cd}"
    export IS_MULTI_CLUSTER=false

    export TENANT_NAME="${CLUSTER_NAME}"

    export REGION="${AWS_DEFAULT_REGION:-us-west-2}"
    export REGION_NICK_NAME=${REGION}
    export PRIMARY_REGION="${REGION}"

    export TENANT_DOMAIN="${CLUSTER_NAME}.ping-oasis.com"
    export PRIMARY_TENANT_DOMAIN="${TENANT_DOMAIN}"
    export GLOBAL_TENANT_DOMAIN="${GLOBAL_TENANT_DOMAIN:-$(echo "${TENANT_DOMAIN}"|sed -e "s/[^.]*.\(.*\)/global.\1/")}"

    export ENV=${BELUGA_ENV_NAME}

    export NEW_RELIC_ENVIRONMENT_NAME=${TENANT_NAME}_${ENV}_${REGION}_k8s-cluster

    export CONFIG_PARENT_DIR=aws
    export CONFIG_REPO_BRANCH=${CI_COMMIT_REF_NAME:-master}

    export ARTIFACT_REPO_URL=s3://${CLUSTER_NAME}-artifacts-bucket
    export PING_ARTIFACT_REPO_URL=https://ping-artifacts.s3-us-west-2.amazonaws.com
    export LOG_ARCHIVE_URL=s3://${CLUSTER_NAME}-logs-bucket
    export PGO_BACKUP_BUCKET_NAME=${CLUSTER_NAME}-backup-bucket
    export BACKUP_URL=s3://${PGO_BACKUP_BUCKET_NAME}

    export MYSQL_SERVICE_HOST=beluga-${CLUSTER_NAME}-mysql.cmpxy5bpieb9.us-west-2.rds.amazonaws.com
    export MYSQL_USER=ssm://aws/reference/secretsmanager//pcpt/ping-central/dbserver#username
    export MYSQL_PASSWORD=ssm://aws/reference/secretsmanager//pcpt/ping-central/dbserver#password

    export AWS_PROFILE=csg

    export LEGACY_LOGGING=False

    export PF_PROVISIONING_ENABLED=true

    export LOG_LINES_TO_TEST=2

    # Service SSM should be available for all environments
    export SERVICE_SSM_PATH_PREFIX="/${SELECTED_KUBE_NAME}/pcpt/service"

    export DASH_REPO_URL="https://github.com/pingidentity/ping-cloud-dashboards"
    export DASH_REPO_BRANCH="main"

  elif test -f "${ENV_VARS_FILE}"; then
    echo "Using environment variables defined in file ${ENV_VARS_FILE}"
    set -a; source "${ENV_VARS_FILE}"; set +a
  else
    echo "ENV_VARS_FILE points to a non-existent file: ${ENV_VARS_FILE}"
    exit 1
  fi

  NEW_RELIC_LICENSE_KEY="${NEW_RELIC_LICENSE_KEY:-ssm://pcpt/sre/new-relic/java-agent-license-key}"
  if [[ ${NEW_RELIC_LICENSE_KEY} == "ssm://"* ]]; then
    if ! ssm_value=$(get_ssm_value "${NEW_RELIC_LICENSE_KEY#ssm:/}"); then
      echo "Warn: ${ssm_value}"
      echo "Setting NEW_RELIC_LICENSE_KEY to unused"
      NEW_RELIC_LICENSE_KEY="unused"
    else
      NEW_RELIC_LICENSE_KEY="${ssm_value}"
    fi
  fi

  export NEW_RELIC_LICENSE_KEY_BASE64=$(base64_no_newlines "${NEW_RELIC_LICENSE_KEY}")
  export DATASYNC_P1AS_SYNC_SERVER="pingdirectory-0"

  # Timing
  export LOG_SYNC_SECONDS="${LOG_SYNC_SECONDS:-5}"
  export UPLOAD_TIMEOUT_SECONDS="${UPLOAD_TIMEOUT_SECONDS:-20}"
  export CURL_TIMEOUT_SECONDS="${CURL_TIMEOUT_SECONDS:-450}"

  export ADMIN_USER=administrator
  export ADMIN_PASS=2FederateM0re

  export PD_SEED_LDAPS_PORT=636

  export CLUSTER_NAME_LC=$(echo "${CLUSTER_NAME}" | tr '[:upper:]' '[:lower:]')
  export LOG_GROUP_NAME="/aws/containerinsights/${CLUSTER_NAME}/application"

  FQDN=${ENVIRONMENT}.${TENANT_DOMAIN}

  # Monitoring
  LOGS_CONSOLE=https://logs${FQDN}/app/kibana
  PROMETHEUS=https://prometheus${FQDN}
  GRAFANA=https://monitoring${FQDN}

  # Pingdirectory
  PINGDIRECTORY_API=https://pingdirectory${FQDN}
  PINGDIRECTORY_ADMIN=pingdirectory-admin${FQDN}

  # Pingfederate
  # admin services:
  PINGFEDERATE_CONSOLE=https://pingfederate-admin${FQDN}/pingfederate/app
  PINGFEDERATE_API=https://pingfederate-admin-api${FQDN}/pf-admin-api/v1/version

  # The trailing / is required to avoid a 302
  PINGFEDERATE_API_DOCS=https://pingfederate-admin${FQDN}/pf-admin-api/api-docs/
  PINGFEDERATE_ADMIN_API=https://pingfederate-admin-api${FQDN}/pf-admin-api/v1

  # runtime services:
  PINGFEDERATE_AUTH_ENDPOINT=https://pingfederate${FQDN}
  PINGFEDERATE_OAUTH_PLAYGROUND=https://pingfederate${FQDN}/OAuthPlayground

  # Pingaccess
  # admin services:
  PINGACCESS_CONSOLE=https://pingaccess-admin${FQDN}
  PINGACCESS_SWAGGER=https://pingaccess-admin${FQDN}/pa-admin-api/api-docs
  PINGACCESS_API=https://pingaccess-admin${FQDN}/pa-admin-api/v3

  # runtime services:
  PINGACCESS_RUNTIME=https://pingaccess${FQDN}
  PINGACCESS_AGENT=https://pingaccess-agent${FQDN}

  # PingAccess WAS
  # admin services:
  # The trailing / is required to avoid a 302
  PINGACCESS_WAS_SWAGGER=https://pingaccess-was-admin${FQDN}/pa-admin-api/v3/api-docs/
  PINGACCESS_WAS_CONSOLE=https://pingaccess-was-admin${FQDN}
  PINGACCESS_WAS_API=https://pingaccess-was-admin${FQDN}/pa-admin-api/v3

  # runtime services:
  PINGACCESS_WAS_RUNTIME=https://pingaccess-was${FQDN}

  # Ping Delegated Admin
  PINGDELEGATOR_CONSOLE=https://pingdelegator${FQDN}/delegator

  # PingCentral
  MYSQL_SERVICE_HOST="beluga-${SELECTED_KUBE_NAME:-ci-cd}-mysql.cmpxy5bpieb9.us-west-2.rds.amazonaws.com"
  MYSQL_SERVICE_PORT=3306
  MYSQL_USER_SSM=/aws/reference/secretsmanager//pcpt/ping-central/dbserver#username
  MYSQL_PASSWORD_SSM=/aws/reference/secretsmanager//pcpt/ping-central/dbserver#password

  # Pingcloud-metadata service:
  PINGCLOUD_METADATA_API=https://metadata${FQDN}

  # Pingcloud-healthcheck service:
  PINGCLOUD_HEALTHCHECK_API=https://healthcheck${FQDN}

  # PingCentral service
  PINGCENTRAL_CONSOLE=https://pingcentral${FQDN}
}

set_deploy_type_env_vars
set_env_vars

########################################################################################################################
# Sets env vars specific to PingOne API integration
########################################################################################################################
set_pingone_api_env_vars() {
  P1_BASE_ENV_VARS=$(get_ssm_val "/pcpt/pingone/env-vars")
  eval $P1_BASE_ENV_VARS
  P1_CLUSTER_ENV_VARS=$(get_ssm_val "/pcpt/pingone/${SELECTED_KUBE_NAME}/env-vars")
  eval $P1_CLUSTER_ENV_VARS
}

########################################################################################################################
# Configures kubectl to be able to talk to the Kubernetes API server based on the following environment variables:
#
#   - SELECTED_KUBE_NAME
#   - AWS_ACCOUNT_ROLE_ARN
#
# If the environment variables are not present, then the function will exit with a non-zero return code.
########################################################################################################################
configure_kube() {
  if test -n "${SKIP_CONFIGURE_KUBE}"; then
    log "Skipping KUBE configuration"
    return
  fi

  check_env_vars "SELECTED_KUBE_NAME" "AWS_ACCOUNT_ROLE_ARN"
  HAS_REQUIRED_VARS=${?}

  if test ${HAS_REQUIRED_VARS} -ne 0; then
    exit 1
  fi

  log "Configuring KUBE"

  # Use AWS profile 'default' because this is the profile the AWS Access Key/Secret key go under in the 'configure_aws'
  # function. This profile then assumes the role specified by $AWS_ACCOUNT_ROLE_ARN, within the kube config.
  aws eks update-kubeconfig \
    --profile "default" \
    --role-arn "${AWS_ACCOUNT_ROLE_ARN}" \
    --alias "${SELECTED_KUBE_NAME}" \
    --name "${SELECTED_KUBE_NAME}" \
    --region us-west-2

  kubectl config use-context "${SELECTED_KUBE_NAME}"
}

########################################################################################################################
# Configures the aws CLI to be able to talk to the AWS API server based on the following environment variables:
#
#   - AWS_ACCESS_KEY_ID
#   - AWS_SECRET_ACCESS_KEY
#   - AWS_DEFAULT_REGION
#   - AWS_ACCOUNT_ROLE_ARN
#
# If the environment variables are not present, then the function will exit with a non-zero return code. The AWS config
# and credentials file will be set up with a profile of ${AWS_PROFILE} environment variable defined in the common.sh
# file.
########################################################################################################################
configure_aws() {
  if test -n "${SKIP_CONFIGURE_AWS}"; then
    log "Skipping AWS CLI configuration"
    return
  fi

  check_env_vars "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_DEFAULT_REGION" "AWS_ACCOUNT_ROLE_ARN" "AWS_PROFILE"
  HAS_REQUIRED_VARS=${?}

  if test ${HAS_REQUIRED_VARS} -ne 0; then
    exit 1
  fi

  log "Configuring AWS CLI"
  mkdir -p ~/.aws

  cat > ~/.aws/config <<EOF
  [default]
  output = json

  [profile ${AWS_PROFILE}]
  output = json
  region = ${AWS_DEFAULT_REGION}
  source_profile = default
  role_arn = ${AWS_ACCOUNT_ROLE_ARN}
EOF

  cat > ~/.aws/credentials <<EOF
  [default]
  aws_access_key_id = ${AWS_ACCESS_KEY_ID}
  aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}

  [${AWS_PROFILE}]
  role_arn = ${AWS_ACCOUNT_ROLE_ARN}
EOF
}

########################################################################################################################
# Retrieve the value associated with the provided parameter from AWS parameter store or AWS Secrets Manager.
#
# Arguments
#   ${1} -> The SSM parameter name.
#
# Returns
#   The value of the parameter name if found, or the error message stating why the command failed.
########################################################################################################################
get_ssm_val() {
  param_name="$1"
  if ! ssm_val="$(aws ssm get-parameters \
            --profile "${AWS_PROFILE}" \
            --region "${REGION}" \
            --names "${param_name%#*}" \
            --query 'Parameters[*].Value' \
            --with-decryption \
            --output text)"; then
    echo "$ssm_val"
    return 1
  fi

  if [[ "$param_name" == *"secretsmanager"* ]]; then
    # grep for the value of the secrets manager object's key
    # the object's key is the string following the '#' in the param_name variable
    echo "$ssm_val" | grep -Eo "${param_name#*#}[^,]*" | grep -Eo "[^:]*$" | tr -d '"'
  else
    echo "$ssm_val"
  fi
}

########################################################################################################################
# Wait for the expected count of a resource until the specified timeout.
#
# Arguments
#   ${1} -> The expected count of the resource.
#   ${2} -> The command to get the actual count of the resource. The execution of the command is expected to return
#           a number.
#   ${3} -> Wait timeout in seconds. Default is 2 minutes.
########################################################################################################################
wait_for_expected_resource_count() {
  EXPECTED=${1}
  COMMAND=${2}
  TIMEOUT_SECONDS=${3:-120}

  TIME_WAITED_SECONDS=0
  SLEEP_SECONDS=5

  while true; do
    ACTUAL=$(eval "${COMMAND}")
    if test ! -z "${ACTUAL}" && test "${ACTUAL}" -eq "${EXPECTED}"; then
      break
    fi

    sleep "${SLEEP_SECONDS}"
    TIME_WAITED_SECONDS=$((TIME_WAITED_SECONDS + SLEEP_SECONDS))

    if test "${TIME_WAITED_SECONDS}" -ge "${TIMEOUT_SECONDS}"; then
      echo "Expected count ${EXPECTED} but found ${ACTUAL} after ${TIMEOUT_SECONDS} seconds"
      return 1
    fi
  done

  return 0
}

########################################################################################################################
# Determine whether to skip the tests in the file with the provided name. If the SKIP_TESTS environment variable is set
# and contains the name of the file with its parent directory, then that test file will be skipped. For example, to
# skip the PingDirectory tests in files 03-backup-restore.sh and 20-pd-recovery-on-delete-pv.sh, set SKIP_TESTS to
# 'pingdirectory/03-backup-restore.sh chaos/20-pd-recovery-on-delete-pv.sh'.
#
# Arguments
#   ${1} -> The fully-qualified name of the test file.
#
# Returns
#   0 -> if the test should be skipped; 1 -> if the test should not be skipped.
########################################################################################################################
skipTest() {
  test -z "${SKIP_TESTS}" && return 1

  local test_file="${1}"

  readonly dir_name=$(basename "$(dirname "${test_file}")")
  readonly file_name=$(basename "${test_file}")
  readonly test_file_short_name="${dir_name}/${file_name}"

  echo "${SKIP_TESTS}" | grep -q "${test_file_short_name}" &> /dev/null

  if test $? -eq 0; then
    log "SKIP_TESTS is set to skip test file: ${test_file_short_name}"
    return 0
  fi

  return 1
}

########################################################################################################################
# Search for password regex pattern within log file.
#
# Arguments
#   ${1} -> Name of server
#   ${2} -> Regex pattern of all passwords used within server
#   ${3} -> Temp file used to store logs
#
# Returns
#   0 -> If product password is not found in logs; 1 -> If password was found in logs
########################################################################################################################
check_for_password_in_logs() {
  set +x
  local server="${1}"
  local pattern="${2}"
  local log_file=${3}

  # Search for password within logs
  local result=$( cat ${log_file} | grep "${pattern}" )

  test -z "${result}" && return 0
  set -x

  # Password found
  log "${server}: password(s) found in log file.
    1) You must resolve this issue. 
    2) Change all existing passwords. 
    3) Rerun test"
  return 1
}

########################################################################################################################
# Get last 60min logs from server and write its output to temp file.
#
# Arguments
#   ${1} -> Name of server
#   ${2} -> Name of pod container
#   ${3} -> Temp file used to store logs
#
########################################################################################################################
set_log_file() {
  local server="${1}"
  local container="${2}"
  local log_file=${3}

  kubectl logs -n "${PING_CLOUD_NAMESPACE}" "${server}" -c "${container}" --since=60m > ${log_file}
}

function find_shunit_dir() {
  # use egrep here or find will always return 0
  find . -type d -name "shunit*" | egrep '.*'
}

function find_shunit_symlink() {
  # use egrep here or find will always return 0
  find . -type l -name shunit | egrep '.*'
}

function prepareShunit() {

  # Check to see if shunit2 is ready
  pushd "${PROJECT_DIR}"/ci-scripts/test/shunit > /dev/null

  shunit_dir_name=$(find_shunit_dir)
  shunit_dir_found=$?

  echo
  if [[ ${shunit_dir_found} -eq 0 ]]; then
    echo "Found ${shunit_dir_name}.  Skipping shunit configuration."
  else
    echo "shunit not found.  Unpacking it..."

    unzip shunit*.zip 1>/dev/null
    shunit_dir_name=$(find_shunit_dir)

    echo "Unpacking of ${shunit_dir_name} complete."
  fi

  popd > /dev/null

  return 0
}

function find_shunit_dir() {
  # use egrep here or find will always return 0
  find . -type d -name "shunit*" | egrep '.*'
}

function find_shunit_symlink() {
  # use egrep here or find will always return 0
  find . -type l -name shunit | egrep '.*'
}

function prepareShunit() {

  # Check to see if shunit2 is ready
  pushd "${PROJECT_DIR}"/ci-scripts/test/shunit > /dev/null

  shunit_dir_name=$(find_shunit_dir)
  shunit_dir_found=$?

  echo
  if [[ ${shunit_dir_found} -eq 0 ]]; then
    echo "Found ${shunit_dir_name}.  Skipping shunit configuration."
  else
    echo "shunit not found.  Unpacking it..."

    unzip shunit*.zip 1>/dev/null
    shunit_dir_name=$(find_shunit_dir)

    echo "Unpacking of ${shunit_dir_name} complete."
  fi

  popd > /dev/null

  return 0
}

########################################################################################################################
# Verifies that the files listed in the expected.txt file are uploaded to S3 in the ${1} directory. Retries up to the
# timeout specified in the UPLOAD_TIMEOUT_SECONDS variable.
#
# Arguments
#   ${1} -> Name of the product directory within S3
########################################################################################################################
verify_upload_with_timeout() {
  local directory_name="${1}"
  local expected_files=/tmp/expected.txt
  local actual_files=/tmp/actual.txt

  local iteration=0
  while true; do
    # sleep for 2 seconds before verifying the upload
    sleep 2

    # update iteration count
    iteration=$((iteration + 1))

    log "Actual files in iteration ${iteration}:"
    actual_files "${directory_name}" | tee "${actual_files}"

    log "Verifying that the expected files were uploaded in iteration ${iteration}:"
    local not_uploaded=$(comm -23 "${expected_files}" "${actual_files}")

    # success
    test -z "${not_uploaded}" && return 0

    # timeout
    local waited_seconds=$((iteration * 2))
    if test "${waited_seconds}" -ge "${UPLOAD_TIMEOUT_SECONDS}"; then
      log "The following files were not uploaded: ${not_uploaded} after a timeout of ${UPLOAD_TIMEOUT_SECONDS} seconds"
      return 1
    fi
  done
}

########################################################################################################################
# Searches AWS s3 bucket and returns CSD support-data files found
#
# Arguments
#   ${1} -> Name of the product directory within S3
########################################################################################################################
actual_files() {
  local directory_name="${1}"
  local bucket_url_no_protocol=${LOG_ARCHIVE_URL#s3://}
  local bucket_name=$(echo "${bucket_url_no_protocol}" | cut -d/ -f1)
  local days_ago=1

  aws s3api list-objects \
    --bucket "${bucket_name}" \
    --prefix "${directory_name}/" \
    --query "reverse(sort_by(Contents[?LastModified>='${days_ago}'], &LastModified))[].Key" \
    --profile "${AWS_PROFILE}" |
  grep support-data |
  tr -d '",[]' |
  cut -d/ -f2 |
  sort
}

########################################################################################################################
# Searches CSD upload job logs and returns CSD support-data files found
#
# Arguments
#   ${1} -> The upload CSD job name
########################################################################################################################
expected_files() {
  local upload_csd_job_pods=$(kubectl get pod -o name -n "${PING_CLOUD_NAMESPACE}" | grep "${1}" | cut -d/ -f2)
  for upload_csd_job_pod in $upload_csd_job_pods; do
    kubectl logs -n "${PING_CLOUD_NAMESPACE}" ${upload_csd_job_pod} |
    tail -1 |
    tr ' ' '\n' |
    sort
  done
}

########################################################################################################################
# Check if the cluster is ready to run integration tests.
# BLOCKS until the cluster is ready, returns when either ready or timeout is reached
#
# A PingDirectory pod can take up to 15 minutes to deploy in the CI/CD cluster. There are two sets of dependencies
# today from:
#
#     1. PA engine -> PA admin -> PF admin -> PD
#     2. PF engine -> PF admin -> PD
#     3. PA WAS engine -> PA WAS admin
#
# So checking the rollout status of the end dependencies should be enough after PD is rolled out. We'll give each 2.5
# minutes after PD is ready. This should be more than enough time because as soon as pingdirectory-0 is ready, the
# rollout of the others will begin, and they don't take nearly as much time as a single PD server. So the entire Ping
# stack must be rolled out in no more than (15 * num of PD replicas + 2.5 * number of end dependents) minutes.
#
# Arguments:
# $1 - the namespace to check
########################################################################################################################
check_if_ready() {
  local ns_to_check=${1}

  local pd_replica='statefulset.apps/pingdirectory'
  local other_ping_app_replicas='statefulset.apps/pingfederate statefulset.apps/pingaccess statefulset.apps/pingaccess-was'

  local num_pd_replicas=$(kubectl get "${pd_replica}" -o jsonpath='{.spec.replicas}' -n "${ns_to_check}")

  local pd_timeout_seconds=$((num_pd_replicas * 900))
  local dependent_timeout_seconds=300

  echo "Waiting for rollout of ${pd_replica} with a timeout of ${pd_timeout_seconds} seconds"
  wait_for_rollout "${pd_replica}" "${ns_to_check}" "${pd_timeout_seconds}"

  for dependent_replica in ${other_ping_app_replicas}; do
    echo "Waiting for rollout of ${dependent_replica} with a timeout of ${dependent_timeout_seconds} seconds"
    wait_for_rollout "${dependent_replica}" "${ns_to_check}" "${dependent_timeout_seconds}"
  done

  # Print out the ingress objects for logs and the ping stack
  printf '\n--- Ingress URLs ---\n'
  kubectl get ingress -A

  # Print out the pingdirectory hostname
  printf '\n--- LDAP hostname ---\n'
  kubectl get svc pingdirectory-admin -n "${ns_to_check}" \
    -o jsonpath='{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}'

  # Print out the  pods for the ping stack
  printf '\n\n--- Pod status ---'
  kubectl get pods -n "${ns_to_check}"
}
