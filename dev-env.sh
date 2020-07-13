#!/bin/bash

########################################################################################################################
#
# This script may be used to set up a development or test environment to verify the Kubernetes and Kustomization yaml
# files either in their present form or after making some local changes to them.
#
# Run the script in the following manner:
#     source <your-env-variables-file>; CONFIG_REPO_BRANCH=$(git rev-parse --abbrev-ref HEAD) ./dev-env.sh
#
# ------------
# Requirements
# ------------
# The script requires the following tools to be installed:
#   - openssl
#   - base64
#   - kustomize
#   - kubectl
#   - envsubst
#
# In addition, the assumption is that kubectl is configured to authenticate and apply manifests to the Kubernetes
# cluster. For EKS clusters, this requires an AWS key and secret with the appropriate IAM policies to be configured and
# requires that the aws CLI tool and probably the aws-iam-authenticator CLI tool are installed.
#
# ------------------
# Usage instructions
# ------------------
# Aside from a -n (dry-run option), the script does not take any parameters but rather acts on environment variables.
# The environment variables will be substituted into the variables in the yaml template files.
#
# Both real and dry run will emit the Kubernetes manifest file for the entire deployment into the file /tmp/deploy.yaml.
# After running the script in dry-run mode, the deploy.yaml file may be edited, if desired, but it should be able to
# be deployed as-is onto the cluster. In fact, this is exactly what gets deployed when the script is run in real
# mode, i.e. without the -n option.
#
# The following mandatory environment variables must be present before running this script.
#
# ----------------------------------------------------------------------------------------------------------------------
# Variable                    | Purpose
# ----------------------------------------------------------------------------------------------------------------------
# PING_IDENTITY_DEVOPS_USER   | A user with license to run Ping Software
# PING_IDENTITY_DEVOPS_KEY    | The key to the above user
#
# In addition, the following environment variables, if present, will be used for the following purposes:
#
# ----------------------------------------------------------------------------------------------------------------------
# Variable                  | Purpose                                            | Default (if not present)
# ----------------------------------------------------------------------------------------------------------------------
# TENANT_NAME               | The name of the tenant, e.g. k8s-icecream. If      | PingPOC
#                           | provided, this value will be used for the cluster  |
#                           | name and must have the correct case (e.g. PingPOC  |
#                           | vs. pingpoc). If not provided, this variable is    |
#                           | not used, and the cluster name defaults to the CDE |
#                           | name. On AWS, the cluster name is a required       |
#                           | parameter to Container Insights, an AWS-specific   |
#                           | logging and monitoring solution, and cluster       |
#                           | autoscaler, which is used for automatic scaling of |
#                           | of Kubernetes worker nodes.                        |
#                           |                                                    |
# ENVIRONMENT               | An environment to isolate the Ping stack into its  | The value of the USER environment
#                           | own namespace within the Kubernetes cluster. The   | variable.
#                           | Ping stack is generally deployed to a namespace    |
#                           | called "ping-cloud". But if ENVIRONMENT is set, it |
#                           | is used as a name suffix. For example, if it is    |
#                           | set to "staging", then the namespace will be       |
#                           | "ping-cloud-staging". This variable is useful not  |
#                           | just in a shared multi-tenant Kubernetes cluster   |
#                           | but could also be used to create multiple Ping     |
#                           | stacks within the same cluster for testing         |
#                           | purposes. It may be set to an empty string in      |
#                           | which case, the namespace used for the Ping stack  |
#                           | will simply be "ping-cloud".                       |
#                           |                                                    |
# TENANT_DOMAIN             | The tenant's domain, e.g. k8s-icecream.com         | eks-poc.au1.ping-lab.cloud
#                           |                                                    |
# REGION                    | The region where the tenant environment is         | us-east-2
#                           | deployed. On AWS, this is a required parameter     |
#                           | to Container Insights, an AWS-specific logging     |
#                           | and monitoring solution.                           |
#                           |                                                    |
# IS_MULTI_CLUSTER          | Flag indicating whether or not this is a           | false
#                           | multi-cluster deployment.                          |
#                           |                                                    |
# PRIMARY_TENANT_DOMAIN     | The tenant's domain in the primary region.         | Same as TENANT_DOMAIN.
#                           | Only used if IS_MULTI_CLUSTER is true.             |
#                           |                                                    |
# PRIMARY_REGION            | The region where the tenant's primary environment  | Same as REGION.
#                           | is deployed. On AWS, this is a required parameter  |
#                           | to Container Insights, an AWS-specific logging     |
#                           | and monitoring solution.                           |
#                           | Only used if IS_MULTI_CLUSTER is true.             |
#                           |                                                    |
# CONFIG_REPO_BRANCH        | The branch within this repository for server       | master
#                           | profiles, i.e. configuration.                      |
#                           |                                                    |
# CONFIG_PARENT_DIR         | The parent directory for server profiles within    | aws
#                           | the "profiles" base directory, e.g. dev, aws, etc. |
#                           |                                                    |
# ARTIFACT_REPO_URL         | The URL for private plugins (e.g. PF kits, PD      | The string "unused".
#                           | extensions). If not provided, the Ping stack will  |
#                           | be provisioned without private plugins. This URL   |
#                           | must use an s3 scheme, e.g.                        |
#                           | s3://customer-repo-bucket-name.                    |
#                           |                                                    |
# PING_ARTIFACT_REPO_URL    | This environment variable can be used to overwrite | https://ping-artifacts.s3-us-west-2.amazonaws.com
#                           | the default endpoint for public plugins. This URL  |
#                           | must use an https scheme as shown by the default   |
#                           | value.                                             |
#                           |                                                    |
# LOG_ARCHIVE_URL           | The URL of the log archives. If provided, logs     | The string "unused"
#                           | are periodically captured and sent to this URL.    |
#                           |                                                    |
# BACKUP_URL                | The URL of the backup location. If provided, data  | The string "unused".
#                           | backups are periodically captured and sent to this |
#                           | URL. For AWS S3 buckets, it must be an S3 URL,     |
#                           | e.g. s3://backups.                                 |
#                           |                                                    |
# CLUSTER_BUCKET_NAME       | The name of the S3 bucket where clustering         | The string "unused". This is a
#                           | information is stored for all stateful Ping apps.  | required property for multi-cluster
#                           |                                                    | deployments, which is currently only
#                           |                                                    | supported on AWS.
#                           |                                                    |
# DEPLOY_FILE               | The name of the file where the final deployment    | /tmp/deploy.yaml
#                           | spec is saved before applying it.                  |
#                           |                                                    |
# K8S_CONTEXT               | The current Kubernetes context, i.e. cluster.      | The current context as set in
#                           | spec is saved before applying it.                  | ~/.kube/config or the config file
#                           |                                                    | to which KUBECONFIG is set.
########################################################################################################################

#
# Ensure we're in the correct directory to run the script.
#
declare -r homeDir=$(dirname ${0})
pushd ${homeDir} > /dev/null 2>&1

# Source devops and aws-eks files, if present
test -f ~/.pingidentity/devops && . ~/.pingidentity/devops

# Source some utility methods.
. utils.sh

declare dryrun='false'
declare skipTest='false'

# Parse Parameters
while getopts 'ns' OPTION
do
  case ${OPTION} in
    n)
      dryrun='true'
      ;;
    s)
      skipTest='true'
      ;;
    *)
      echo "Usage ${0} [ -ns ] n = dry-run; s = skip-test"
      popd  > /dev/null 2>&1
      exit 1
      ;;
  esac
done

# Checking required tools and environment variables.
check_binaries "openssl" "base64" "kustomize" "kubectl" "envsubst"
HAS_REQUIRED_TOOLS=${?}

check_env_vars "PING_IDENTITY_DEVOPS_USER" "PING_IDENTITY_DEVOPS_KEY"
HAS_REQUIRED_VARS=${?}

if test ${HAS_REQUIRED_TOOLS} -ne 0 || test ${HAS_REQUIRED_VARS} -ne 0; then
  popd  > /dev/null 2>&1
  exit 1
fi

test -z "${IS_MULTI_CLUSTER}" && IS_MULTI_CLUSTER=false
if "${IS_MULTI_CLUSTER}"; then
  check_env_vars "CLUSTER_BUCKET_NAME"
  if test $? -ne 0; then
    popd
    exit 1
  fi
fi

# Show initial values for relevant environment variables.
echo "Initial TENANT_NAME: ${TENANT_NAME}"
echo "Initial ENVIRONMENT: ${ENVIRONMENT}"

echo "Initial IS_MULTI_CLUSTER: ${IS_MULTI_CLUSTER}"
echo "Initial CLUSTER_BUCKET_NAME: ${CLUSTER_BUCKET_NAME}"
echo "Initial REGION: ${REGION}"
echo "Initial PRIMARY_REGION: ${PRIMARY_REGION}"
echo "Initial TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Initial PRIMARY_TENANT_DOMAIN: ${PRIMARY_TENANT_DOMAIN}"

echo "Initial CONFIG_REPO_BRANCH: ${CONFIG_REPO_BRANCH}"
echo "Initial CONFIG_PARENT_DIR: ${CONFIG_PARENT_DIR}"

echo "Initial ARTIFACT_REPO_URL: ${ARTIFACT_REPO_URL}"
echo "Initial PING_ARTIFACT_REPO_URL: ${PING_ARTIFACT_REPO_URL}"
echo "Initial LOG_ARCHIVE_URL: ${LOG_ARCHIVE_URL}"
echo "Initial BACKUP_URL: ${BACKUP_URL}"

echo "Initial DEPLOY_FILE: ${DEPLOY_FILE}"
echo "Initial K8S_CONTEXT: ${K8S_CONTEXT}"
echo ---

# A script that may be used to set up a dev/test environment against the
# current cluster. Must have the GTE devops user and key exported as
# environment variables.
export TENANT_NAME="${TENANT_NAME:-PingPOC}"
export ENVIRONMENT=-"${ENVIRONMENT:-${USER}}"

export IS_MULTI_CLUSTER="${IS_MULTI_CLUSTER}"
export CLUSTER_BUCKET_NAME="${CLUSTER_BUCKET_NAME}"

export REGION="${REGION:-us-east-2}"
export PRIMARY_REGION="${PRIMARY_REGION:-${REGION}}"

export TENANT_DOMAIN="${TENANT_DOMAIN:-eks-poc.au1.ping-lab.cloud}"
export PRIMARY_TENANT_DOMAIN="${PRIMARY_TENANT_DOMAIN:-${TENANT_DOMAIN}}"

export CONFIG_REPO_BRANCH="${CONFIG_REPO_BRANCH:-master}"
export CONFIG_PARENT_DIR="${CONFIG_PARENT_DIR:-aws}"

export ARTIFACT_REPO_URL="${ARTIFACT_REPO_URL:-unused}"
export PING_ARTIFACT_REPO_URL="${PING_ARTIFACT_REPO_URL:-https://ping-artifacts.s3-us-west-2.amazonaws.com}"
export LOG_ARCHIVE_URL="${LOG_ARCHIVE_URL:-unused}"
export BACKUP_URL="${BACKUP_URL:-unused}"

DEPLOY_FILE=${DEPLOY_FILE:-/tmp/deploy.yaml}
test -z "${K8S_CONTEXT}" && K8S_CONTEXT=$(kubectl config current-context)

ENVIRONMENT_NO_HYPHEN_PREFIX="${ENVIRONMENT#-}"

# Show the values being used for the relevant environment variables.
echo "Using TENANT_NAME: ${TENANT_NAME}"
echo "Using ENVIRONMENT: ${ENVIRONMENT_NO_HYPHEN_PREFIX}"

echo "Using IS_MULTI_CLUSTER: ${IS_MULTI_CLUSTER}"
echo "Using CLUSTER_BUCKET_NAME: ${CLUSTER_BUCKET_NAME}"
echo "Using REGION: ${REGION}"
echo "Using PRIMARY_REGION: ${PRIMARY_REGION}"
echo "Using TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Using PRIMARY_TENANT_DOMAIN: ${PRIMARY_TENANT_DOMAIN}"

echo "Using CONFIG_REPO_BRANCH: ${CONFIG_REPO_BRANCH}"
echo "Using CONFIG_PARENT_DIR: ${CONFIG_PARENT_DIR}"

echo "Using ARTIFACT_REPO_URL: ${ARTIFACT_REPO_URL}"
echo "Using PING_ARTIFACT_REPO_URL: ${PING_ARTIFACT_REPO_URL}"
echo "Using LOG_ARCHIVE_URL: ${LOG_ARCHIVE_URL}"
echo "Using BACKUP_URL: ${BACKUP_URL}"

echo "Using DEPLOY_FILE: ${DEPLOY_FILE}"
echo "Using K8S_CONTEXT: ${K8S_CONTEXT}"
echo ---

export PING_IDENTITY_DEVOPS_USER_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_USER}")
export PING_IDENTITY_DEVOPS_KEY_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_KEY}")

export CLUSTER_NAME=${TENANT_NAME}
export CLUSTER_NAME_LC=$(echo ${CLUSTER_NAME} | tr '[:upper:]' '[:lower:]')

export NAMESPACE=ping-cloud-${ENVIRONMENT_NO_HYPHEN_PREFIX}

# Set the cluster type based on primary or secondary.
DEV_CLUSTER_STATE_DIR=dev-cluster-state

if "${IS_MULTI_CLUSTER}" && test "${TENANT_DOMAIN}" != "${PRIMARY_TENANT_DOMAIN}"; then
  CLUSTER_TYPE=secondary
fi

kustomize build "${DEV_CLUSTER_STATE_DIR}/${CLUSTER_TYPE}" |
  envsubst '${PING_IDENTITY_DEVOPS_USER_BASE64}
    ${PING_IDENTITY_DEVOPS_KEY_BASE64}
    ${ENVIRONMENT}
    ${IS_MULTI_CLUSTER}
    ${CLUSTER_BUCKET_NAME}
    ${REGION}
    ${PRIMARY_REGION}
    ${TENANT_DOMAIN}
    ${PRIMARY_TENANT_DOMAIN}
    ${CLUSTER_NAME}
    ${CLUSTER_NAME_LC}
    ${NAMESPACE}
    ${CONFIG_REPO_BRANCH}
    ${CONFIG_PARENT_DIR}
    ${ARTIFACT_REPO_URL}
    ${PING_ARTIFACT_REPO_URL}
    ${LOG_ARCHIVE_URL}
    ${BACKUP_URL}' > "${DEPLOY_FILE}"

sed -i.bak -E "s/((namespace|name): )ping-cloud$/\1${NAMESPACE}/g" "${DEPLOY_FILE}"

if test "${dryrun}" = 'false'; then
  echo "Deploying ${DEPLOY_FILE} to cluster ${CLUSTER_NAME}, namespace ${NAMESPACE} for tenant ${TENANT_DOMAIN}"
  kubectl apply -f "${DEPLOY_FILE}" --context "${K8S_CONTEXT}"

  # Print out the ingress objects for logs and the ping stack
  echo
  echo '--- Ingress URLs ---'
  kubectl get ingress -A --context "${K8S_CONTEXT}"

  # Print out the pingdirectory hostname
  echo
  echo '--- LDAP hostname ---'
  kubectl get svc ingress-nginx -n ingress-nginx-private \
    -o jsonpath='{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}' \
    --context "${K8S_CONTEXT}"

  # Print out the  pods for the ping stack
  echo
  echo
  echo '--- Pod status ---'
  kubectl get pods -n "${NAMESPACE}" --context "${K8S_CONTEXT}"

  echo
  if test "${skipTest}" = 'true'; then
    echo "Skipping integration and unit tests"
  else
    echo "Waiting for pods in ${NAMESPACE} to be ready"

    for DEPLOYMENT in $(kubectl get statefulset,deployment -n "${NAMESPACE}" -o name --context "${K8S_CONTEXT}"); do
      NUM_REPLICAS=$(kubectl get "${DEPLOYMENT}" -o jsonpath='{.spec.replicas}' \
          -n "${NAMESPACE}" --context "${K8S_CONTEXT}")
      TIMEOUT=$((NUM_REPLICAS * 900))
      time kubectl rollout status --timeout "${TIMEOUT}"s "${DEPLOYMENT}" \
          -n "${NAMESPACE}" -w --context "${K8S_CONTEXT}"
    done


    TEST_ENV_VARS_FILE=$(mktemp)
    cat > "${TEST_ENV_VARS_FILE}" <<EOF
export CLUSTER_NAME=${TENANT_NAME}

export IS_MULTI_CLUSTER=${IS_MULTI_CLUSTER}
export CLUSTER_BUCKET_NAME=${CLUSTER_BUCKET_NAME}

export REGION=${REGION}
export PRIMARY_REGION=${PRIMARY_REGION}

export TENANT_DOMAIN=${TENANT_DOMAIN}
export PRIMARY_TENANT_DOMAIN=${PRIMARY_TENANT_DOMAIN}

export ENVIRONMENT=${ENVIRONMENT}
export NAMESPACE=${NAMESPACE}

export CONFIG_PARENT_DIR=aws
export CONFIG_REPO_BRANCH=${CONFIG_REPO_BRANCH}

export ARTIFACT_REPO_URL=${ARTIFACT_REPO_URL}
export PING_ARTIFACT_REPO_URL=${PING_ARTIFACT_REPO_URL}
export LOG_ARCHIVE_URL=${LOG_ARCHIVE_URL}
export BACKUP_URL=${BACKUP_URL}

export PROJECT_DIR=${PWD}
export AWS_PROFILE=${AWS_PROFILE:-csg}

# Other dev-env specific variables
export SKIP_CONFIGURE_KUBE=true
export SKIP_CONFIGURE_AWS=true

export DEV_TEST_ENV=true
EOF
  echo "Running unit tests"
  for unit_test_dir in common pingaccess ci-script-tests; do
    echo
    echo "=========================================================="
    echo "      Executing unit tests in directory: ${unit_test_dir}            "
    echo "=========================================================="
    ci-scripts/test/unit/run-unit-test.sh "${unit_test_dir}" "${TEST_ENV_VARS_FILE}"
  done
  echo

  echo "Running integration tests"
  for integration_test_dir in common pingaccess pingdirectory pingfederate chaos; do
    echo
    echo "=========================================================="
    echo "      Executing tests in directory: ${integration_test_dir}            "
    echo "=========================================================="
    ci-scripts/test/integration/run-test.sh "${integration_test_dir}" "${TEST_ENV_VARS_FILE}"
  done

  fi
else
  less "${DEPLOY_FILE}"
fi

popd  > /dev/null 2>&1
