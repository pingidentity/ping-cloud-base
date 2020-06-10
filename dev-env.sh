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
# TENANT_DOMAIN             | The tenant's domain, e.g. k8s-icecream.com         | eks-poc.au1.ping-lab.cloud
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
# REGION                    | The region where the tenant environment is         | us-east-2
#                           | deployed. On AWS, this is a required parameter     |
#                           | to Container Insights, an AWS-specific logging     |
#                           | and monitoring solution.                           |
#                           |                                                    |
# IS_PARENT                 | Flag indicating whether or not this is the parent  | true
#                           | Kubernetes cluster or region.                      |
#                           |                                                    |
# PD_PARENT_PUBLIC_HOSTNAME | The public or external hostname of the             | pingdirectory-admin${ENVIRONMENT}.${TENANT_DOMAIN}
#                           | PingDirectory server in the parent cluster if      |
#                           | deploying across more than one cluster.            |
#                           |                                                    |
# PF_ADMIN_PUBLIC_HOSTNAME  | The public or external hostname of the             | pingfederate-admin${ENVIRONMENT}.${TENANT_DOMAIN}
#                           | PingFederate admin server.                         |
#                           |                                                    |
# PA_ADMIN_PUBLIC_HOSTNAME  | The public or external hostname of the PingAccess  | pingaccess-admin${ENVIRONMENT}.${TENANT_DOMAIN}
#                           | admin server.                                      |
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
#                           |                                                    | supported on AWS. A bucket with this
#                           |                                                    | name must exist in every region that
#                           |                                                    | the clusters span, and bucket syncing
#                           |                                                    | must be enabled on AWS S3.
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

# Show initial values for relevant environment variables.
echo "Initial TENANT_NAME: ${TENANT_NAME}"
echo "Initial TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Initial ENVIRONMENT: ${ENVIRONMENT}"
echo "Initial REGION: ${REGION}"
echo "Initial IS_PARENT: ${IS_PARENT}"
echo "Initial PD_PARENT_PUBLIC_HOSTNAME: ${PD_PARENT_PUBLIC_HOSTNAME}"
echo "Initial PF_ADMIN_PUBLIC_HOSTNAME: ${PF_ADMIN_PUBLIC_HOSTNAME}"
echo "Initial PA_ADMIN_PUBLIC_HOSTNAME: ${PA_ADMIN_PUBLIC_HOSTNAME}"
echo "Initial CONFIG_REPO_BRANCH: ${CONFIG_REPO_BRANCH}"
echo "Initial CONFIG_PARENT_DIR: ${CONFIG_PARENT_DIR}"
echo "Initial ARTIFACT_REPO_URL: ${ARTIFACT_REPO_URL}"
echo "Initial PING_ARTIFACT_REPO_URL: ${PING_ARTIFACT_REPO_URL}"
echo "Initial LOG_ARCHIVE_URL: ${LOG_ARCHIVE_URL}"
echo "Initial BACKUP_URL: ${BACKUP_URL}"
echo "Initial CLUSTER_BUCKET_NAME: ${CLUSTER_BUCKET_NAME}"
echo "Initial DEPLOY_FILE: ${DEPLOY_FILE}"
echo "Initial K8S_CONTEXT: ${K8S_CONTEXT}"
echo ---

# A script that may be used to set up a dev/test environment against the
# current cluster. Must have the GTE devops user and key exported as
# environment variables.
export ENVIRONMENT=-"${ENVIRONMENT:-${USER}}"
export TENANT_DOMAIN="${TENANT_DOMAIN:-eks-poc.au1.ping-lab.cloud}"
export TENANT_NAME="${TENANT_NAME:-PingPOC}"
export REGION="${REGION:-us-east-2}"

export CONFIG_REPO_BRANCH="${CONFIG_REPO_BRANCH:-master}"
export CONFIG_PARENT_DIR="${CONFIG_PARENT_DIR:-aws}"

export ARTIFACT_REPO_URL="${ARTIFACT_REPO_URL:-unused}"
export PING_ARTIFACT_REPO_URL="${PING_ARTIFACT_REPO_URL:-https://ping-artifacts.s3-us-west-2.amazonaws.com}"
export LOG_ARCHIVE_URL="${LOG_ARCHIVE_URL:-unused}"
export BACKUP_URL="${BACKUP_URL:-unused}"
export CLUSTER_BUCKET_NAME="${CLUSTER_BUCKET_NAME:-unused}"

DEPLOY_FILE=${DEPLOY_FILE:-/tmp/deploy.yaml}
test -z "${K8S_CONTEXT}" && K8S_CONTEXT=$(kubectl config current-context)

ENVIRONMENT_NO_HYPHEN_PREFIX="${ENVIRONMENT#-}"

test -z "${IS_PARENT}" && IS_PARENT=true
test -z "${PD_PARENT_PUBLIC_HOSTNAME}" && export PD_PARENT_PUBLIC_HOSTNAME=pingdirectory-admin${ENVIRONMENT}.${TENANT_DOMAIN}
test -z "${PF_ADMIN_PUBLIC_HOSTNAME}" && export PF_ADMIN_PUBLIC_HOSTNAME=pingfederate-admin${ENVIRONMENT}.${TENANT_DOMAIN}
test -z "${PA_ADMIN_PUBLIC_HOSTNAME}" && export PA_ADMIN_PUBLIC_HOSTNAME=pingaccess-admin${ENVIRONMENT}.${TENANT_DOMAIN}

# Show the values being used for the relevant environment variables.
echo "Using TENANT_NAME: ${TENANT_NAME}"
echo "Using TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Using ENVIRONMENT: ${ENVIRONMENT_NO_HYPHEN_PREFIX}"
echo "Using REGION: ${REGION}"
echo "Using IS_PARENT: ${IS_PARENT}"
echo "Using PD_PARENT_PUBLIC_HOSTNAME: ${PD_PARENT_PUBLIC_HOSTNAME}"
echo "Using PF_ADMIN_PUBLIC_HOSTNAME: ${PF_ADMIN_PUBLIC_HOSTNAME}"
echo "Using PA_ADMIN_PUBLIC_HOSTNAME: ${PA_ADMIN_PUBLIC_HOSTNAME}"
echo "Using CONFIG_REPO_BRANCH: ${CONFIG_REPO_BRANCH}"
echo "Using CONFIG_PARENT_DIR: ${CONFIG_PARENT_DIR}"
echo "Using ARTIFACT_REPO_URL: ${ARTIFACT_REPO_URL}"
echo "Using PING_ARTIFACT_REPO_URL: ${PING_ARTIFACT_REPO_URL}"
echo "Using LOG_ARCHIVE_URL: ${LOG_ARCHIVE_URL}"
echo "Using BACKUP_URL: ${BACKUP_URL}"
echo "Using CLUSTER_BUCKET_NAME: ${CLUSTER_BUCKET_NAME}"
echo "Using DEPLOY_FILE: ${DEPLOY_FILE}"
echo "Using K8S_CONTEXT: ${K8S_CONTEXT}"
echo ---

export PING_IDENTITY_DEVOPS_USER_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_USER}")
export PING_IDENTITY_DEVOPS_KEY_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_KEY}")

export CLUSTER_NAME=${TENANT_NAME}
export CLUSTER_NAME_LC=$(echo ${CLUSTER_NAME} | tr '[:upper:]' '[:lower:]')

export NAMESPACE=ping-cloud-${ENVIRONMENT_NO_HYPHEN_PREFIX}

# Set the cluster type based on parent or child
BELUGA_DEV_TEST_DIR=test
TEST_KUSTOMIZATION="${BELUGA_DEV_TEST_DIR}"/ping-cloud/kustomization.yaml

if "${IS_PARENT}"; then
  export CLUSTER_TYPE=parent
  export PF_PA_ADMIN_INGRESS_PATCHES="$(cat "${BELUGA_DEV_TEST_DIR}"/ping-cloud/pf-pa-admin-ingress-patches.yaml)"
else
  export CLUSTER_TYPE=child
fi

envsubst '${CLUSTER_TYPE}
  ${PF_PA_ADMIN_INGRESS_PATCHES}' < "${TEST_KUSTOMIZATION}".subst > "${TEST_KUSTOMIZATION}"

kustomize build "${BELUGA_DEV_TEST_DIR}" |
  envsubst '${PING_IDENTITY_DEVOPS_USER_BASE64}
    ${PING_IDENTITY_DEVOPS_KEY_BASE64}
    ${ENVIRONMENT}
    ${TENANT_DOMAIN}
    ${CLUSTER_NAME}
    ${CLUSTER_NAME_LC}
    ${REGION}
    ${NAMESPACE}
    ${CONFIG_REPO_BRANCH}
    ${CONFIG_PARENT_DIR}
    ${PD_PARENT_PUBLIC_HOSTNAME}
    ${PF_ADMIN_PUBLIC_HOSTNAME}
    ${PA_ADMIN_PUBLIC_HOSTNAME}
    ${ARTIFACT_REPO_URL}
    ${PING_ARTIFACT_REPO_URL}
    ${LOG_ARCHIVE_URL}
    ${BACKUP_URL}
    ${CLUSTER_BUCKET_NAME}' > "${DEPLOY_FILE}"

sed -i.bak -E "s/((namespace|name): )ping-cloud$/\1${NAMESPACE}/g" "${DEPLOY_FILE}"
rm -f "${TEST_KUSTOMIZATION}"

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
    echo "Skipping integration tests"
  else
    echo "Waiting for pods in ${NAMESPACE} to be ready"

    for DEPLOYMENT in $(kubectl get statefulset,deployment -n "${NAMESPACE}" -o name --context "${K8S_CONTEXT}"); do
      NUM_REPLICAS=$(kubectl get "${DEPLOYMENT}" -o jsonpath='{.spec.replicas}' \
          -n "${NAMESPACE}" --context "${K8S_CONTEXT}")
      TIMEOUT=$((NUM_REPLICAS * 900))
      time kubectl rollout status --timeout "${TIMEOUT}"s "${DEPLOYMENT}" \
          -n "${NAMESPACE}" -w --context "${K8S_CONTEXT}"
    done

    echo "Running integration tests"

    TEST_ENV_VARS_FILE=$(mktemp)
    cat > "${TEST_ENV_VARS_FILE}" <<EOF
export REGION=${REGION}
export CLUSTER_NAME=${TENANT_NAME}
export TENANT_DOMAIN=${TENANT_DOMAIN}

export ENVIRONMENT=${ENVIRONMENT}
export NAMESPACE=${NAMESPACE}

export CONFIG_PARENT_DIR=aws
export CONFIG_REPO_BRANCH=${CONFIG_REPO_BRANCH}

export PD_PARENT_PUBLIC_HOSTNAME=${PD_PARENT_PUBLIC_HOSTNAME}
export PF_ADMIN_PUBLIC_HOSTNAME=${PF_ADMIN_PUBLIC_HOSTNAME}
export PA_ADMIN_PUBLIC_HOSTNAME=${PA_ADMIN_PUBLIC_HOSTNAME}

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

  for TEST_DIR in pingaccess pingdirectory pingfederate integration chaos; do
    echo
    echo "=========================================================="
    echo "      Executing tests in directory ${TEST_DIR}            "
    echo "=========================================================="
    ci-scripts/test/run-test.sh "${TEST_DIR}" "${TEST_ENV_VARS_FILE}"
  done

  fi
else
  less "${DEPLOY_FILE}"
fi

popd  > /dev/null 2>&1
