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
# Variable        | Purpose                                            | Default (if not present)
# ----------------------------------------------------------------------------------------------------------------------
# TENANT_NAME     | The name of the tenant, e.g. k8s-icecream. This    | PingPOC
#                 | will be assumed to be the name of the Kubernetes   |
#                 | cluster. On AWS, the cluster name is a required    |
#                 | parameter to Container Insights, an AWS-specific   |
#                 | logging and monitoring solution.                   |
#                 |                                                    |
# TENANT_DOMAIN   | The tenant's domain, e.g. k8s-icecream.com         | eks-poc.au1.ping-lab.cloud
#                 |                                                    |
# ENVIRONMENT     | An environment to isolate the Ping stack into its  | The value of the USER environment variable.
#                 | own namespace within the Kubernetes cluster. The   |
#                 | Ping stack is generally deployed to a namespace    |
#                 | called "ping-cloud". But if ENVIRONMENT is set, it |
#                 | is used as a name suffix. For example, if it is    |
#                 | set to "staging", then the namespace will be       |
#                 | "ping-cloud-staging". This variable is useful not  |
#                 | just in a shared multi-tenant Kubernetes cluster   |
#                 | but could also be used to create multiple Ping     |
#                 | stacks within the same cluster for testing         |
#                 | purposes. It may be set to an empty string in      |
#                 | which case, the namespace used for the Ping stack  |
#                 | will simply be "ping-cloud".                       |
#                 |                                                    |
# REGION          | The region where the tenant environment is         | us-east-2
#                 | deployed. On AWS, this is a required parameter     |
#                 | to Container Insights, an AWS-specific logging     |
#                 | and monitoring solution.                           |
#                 |                                                    |
# LOG_ARCHIVE_URL | The URL of the log archives. If provided, logs     | No default
#                 | are periodically captured and sent to this URL.    |
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
echo "Initial LOG_ARCHIVE_URL: ${LOG_ARCHIVE_URL}"
echo ---

# A script that may be used to set up a dev/test environment against the
# current cluster. Must have the GTE devops user and key exported as
# environment variables.
export ENVIRONMENT=-"${ENVIRONMENT:-${USER}}"
export TENANT_DOMAIN="${TENANT_DOMAIN:-eks-poc.au1.ping-lab.cloud}"
export TENANT_NAME="${TENANT_NAME:-PingPOC}"
export REGION="${REGION:-us-east-2}"
export LOG_ARCHIVE_URL="${LOG_ARCHIVE_URL}"

ENVIRONMENT_NO_HYPHEN_PREFIX=$(echo ${ENVIRONMENT#-})

# Show the values being used for the relevant environment variables.
echo "Using TENANT_NAME: ${TENANT_NAME}"
echo "Using TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Using ENVIRONMENT: ${ENVIRONMENT_NO_HYPHEN_PREFIX}"
echo "Using REGION: ${REGION}"
echo "Using LOG_ARCHIVE_URL: ${LOG_ARCHIVE_URL}"

export PING_IDENTITY_DEVOPS_USER_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_USER}")
export PING_IDENTITY_DEVOPS_KEY_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_KEY}")
export CLUSTER_NAME=${TENANT_NAME}

NAMESPACE=ping-cloud-${ENVIRONMENT_NO_HYPHEN_PREFIX}
DEPLOY_FILE=/tmp/deploy.yaml

# Generate a self-signed cert for the tenant domain.
generate_tls_cert "${TENANT_DOMAIN}"

kustomize build test |
  envsubst '${PING_IDENTITY_DEVOPS_USER_BASE64}
    ${PING_IDENTITY_DEVOPS_KEY_BASE64}
    ${ENVIRONMENT}
    ${TENANT_DOMAIN}
    ${CLUSTER_NAME}
    ${REGION}
    ${LOG_ARCHIVE_URL}
    ${TLS_CRT_BASE64}
    ${TLS_KEY_BASE64}' > ${DEPLOY_FILE}
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
