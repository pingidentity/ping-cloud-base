#!/bin/bash 

########################################################################################################################
#
# This script may be used to set up a development or test environment to verify the Kubernetes and Kustomization yaml
# files either in their present form or after making some local changes to them.
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
# Variable               | Purpose                                            | Default (if not present)
# ----------------------------------------------------------------------------------------------------------------------
# TENANT_NAME            | The name of the tenant, e.g. k8s-icecream. If      | PingPOC
#                        | provided, this value will be used for the cluster  |
#                        | name and must have the correct case (e.g. PingPOC  |
#                        | vs. pingpoc). If not provided, this variable is    |
#                        | not used, and the cluster name defaults to the CDE |
#                        | name. On AWS, the cluster name is a required       |
#                        | parameter to Container Insights, an AWS-specific   |
#                        | logging and monitoring solution, and cluster       |
#                        | autoscaler, which is used for automatic scaling of |
#                        | of Kubernetes worker nodes.                        |
#                        |                                                    |
# TENANT_DOMAIN          | The tenant's domain, e.g. k8s-icecream.com         | eks-poc.au1.ping-lab.cloud
#                        |                                                    |
# ENVIRONMENT            | An environment to isolate the Ping stack into its  | The value of the USER environment
#                        | own namespace within the Kubernetes cluster. The   | variable.
#                        | Ping stack is generally deployed to a namespace    |
#                        | called "ping-cloud". But if ENVIRONMENT is set, it |
#                        | is used as a name suffix. For example, if it is    |
#                        | set to "staging", then the namespace will be       |
#                        | "ping-cloud-staging". This variable is useful not  |
#                        | just in a shared multi-tenant Kubernetes cluster   |
#                        | but could also be used to create multiple Ping     |
#                        | stacks within the same cluster for testing         |
#                        | purposes. It may be set to an empty string in      |
#                        | which case, the namespace used for the Ping stack  |
#                        | will simply be "ping-cloud".                       |
#                        |                                                    |
# REGION                 | The region where the tenant environment is         | us-east-2
#                        | deployed. On AWS, this is a required parameter     |
#                        | to Container Insights, an AWS-specific logging     |
#                        | and monitoring solution.                           |
#                        |                                                    |
# CONFIG_REPO_BRANCH     | The branch within this repository for server       | master
#                        | profiles, i.e. configuration.                      |
#                        |                                                    |
# CONFIG_PARENT_DIR      | The parent directory for server profiles within    | aws
#                        | the "profiles" base directory, e.g. dev, aws, etc. |
#                        |                                                    |
# ARTIFACT_REPO_URL      | The URL for private plugins (e.g. PF kits, PD      | The string "unused".
#                        | extensions). If not provided, the Ping stack will  |
#                        | be provisioned without private plugins. This URL   |
#                        | must use an s3 scheme, e.g.                        |
#                        | s3://customer-repo-bucket-name.                    |
#                        |                                                    |
# PING_ARTIFACT_REPO_URL | This environment variable can be used to overwrite | https://ping-artifacts.s3-us-west-2.amazonaws.com
#                        | the default endpoint for public plugins. This URL  |
#                        | must use an https scheme as shown by the default   |
#                        | value.                                             |
#                        |                                                    |
# LOG_ARCHIVE_URL        | The URL of the log archives. If provided, logs     | The string "unused"
#                        | are periodically captured and sent to this URL.    |
#                        |                                                    |
# BACKUP_URL             | The URL of the backup location. If provided, data  | The string "unused".
#                        | backups are periodically captured and sent to this |
#                        | URL. For AWS S3 buckets, it must be an S3 URL,     |
#                        | e.g. s3://backups.                                 |
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

declare dryrun="false"

# Parse Parameters
while getopts 'n' OPTION
do
  case ${OPTION} in
    n)
      dryrun='true'
      ;;
    *)
      echo "Usage ${0} [ -n ] n = dry-run"
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
echo "Initial CONFIG_REPO_BRANCH: ${CONFIG_REPO_BRANCH}"
echo "Initial CONFIG_PARENT_DIR: ${CONFIG_PARENT_DIR}"
echo "Initial ARTIFACT_REPO_URL: ${ARTIFACT_REPO_URL}"
echo "Initial PING_ARTIFACT_REPO_URL: ${PING_ARTIFACT_REPO_URL}"
echo "Initial LOG_ARCHIVE_URL: ${LOG_ARCHIVE_URL}"
echo "Initial BACKUP_URL: ${BACKUP_URL}"
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

ENVIRONMENT_NO_HYPHEN_PREFIX=$(echo ${ENVIRONMENT#-})

# Show the values being used for the relevant environment variables.
echo "Using TENANT_NAME: ${TENANT_NAME}"
echo "Using TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Using ENVIRONMENT: ${ENVIRONMENT_NO_HYPHEN_PREFIX}"
echo "Using REGION: ${REGION}"
echo "Using CONFIG_REPO_BRANCH: ${CONFIG_REPO_BRANCH}"
echo "Using CONFIG_PARENT_DIR: ${CONFIG_PARENT_DIR}"
echo "Using ARTIFACT_REPO_URL: ${ARTIFACT_REPO_URL}"
echo "Using PING_ARTIFACT_REPO_URL: ${PING_ARTIFACT_REPO_URL}"
echo "Using LOG_ARCHIVE_URL: ${LOG_ARCHIVE_URL}"
echo "Using BACKUP_URL: ${BACKUP_URL}"
echo ---

export PING_IDENTITY_DEVOPS_USER_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_USER}")
export PING_IDENTITY_DEVOPS_KEY_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_KEY}")

export CLUSTER_NAME=${TENANT_NAME}
export CLUSTER_NAME_LC=$(echo ${CLUSTER_NAME} | tr '[:upper:]' '[:lower:]')

export NAMESPACE=ping-cloud-${ENVIRONMENT_NO_HYPHEN_PREFIX}
DEPLOY_FILE=/tmp/deploy.yaml

kustomize build test |
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
    ${ARTIFACT_REPO_URL}
    ${PING_ARTIFACT_REPO_URL}
    ${LOG_ARCHIVE_URL}
    ${BACKUP_URL}' > ${DEPLOY_FILE}
sed -i.bak -E "s/((namespace|name): )ping-cloud$/\1${NAMESPACE}/g" ${DEPLOY_FILE}

if test "${dryrun}" = 'false'; then
  echo "Deploying ${DEPLOY_FILE} to namespace ${NAMESPACE} for tenant ${TENANT_DOMAIN}"
  kubectl apply -f ${DEPLOY_FILE}

  # Print out the ingress objects for logs and the ping stack
  echo
  echo '--- Ingress URLs ---'
  kubectl get ingress -A

  # Print out the pingdirectory hostname
  echo
  echo '--- LDAP hostname ---'
  kubectl get svc pingdirectory-admin -n ${NAMESPACE} \
    -o jsonpath='{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}'

  # Print out the  pods for the ping stack
  echo
  echo
  echo '--- Pod status ---'
  kubectl get pods -n ${NAMESPACE}
else
  less "${DEPLOY_FILE}"
fi

popd  > /dev/null 2>&1
