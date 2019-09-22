#!/bin/bash
set -x

##########################################################################
# The list of variables in the template files that will be substituted.
##########################################################################
VARS='${PING_IDENTITY_DEVOPS_USER_BASE64}
${PING_IDENTITY_DEVOPS_KEY_BASE64}
${TENANT_DOMAIN}
${REGION}
${SIZE}
${TLS_CERT_ARN}
${CLUSTER_NAME}
${CUSTOMER_REPO_URL}
${KUSTOMIZE_BASE}'

##########################################################################
# Substitute variables in all template files in the provided directory.
#
# Arguments
#   ${1} -> The directory that contains the template files.
##########################################################################
substitute_vars() {
  SUBST_DIR=${1}
  for FILE in $(find "${SUBST_DIR}" -type f); do
    EXTENSION="${FILE##*.}"
    if test "${EXTENSION}" = 'tmpl'; then
      TARGET_FILE="${FILE%.*}"
      envsubst "${VARS}" < "${FILE}" > "${TARGET_FILE}"
      rm -f "${FILE}"
    fi
  done
}

##########################################################################
# Verify that required environment variables are set.
#
# Arguments
#   ${*} -> The list of required environment variables.
##########################################################################
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

# Ensure that the DEVOPS key and user are exported as enrivonment variables.
check_env_vars "PING_IDENTITY_DEVOPS_USER" "PING_IDENTITY_DEVOPS_KEY"
if test ${?} -ne 0; then
  exit 1
fi

# Use defaults for other variables, if not present.
export SIZE="${SIZE:-small}"
export TENANT_NAME="${TENANT_NAME:-PingPOC}"
export TENANT_DOMAIN="${TENANT_DOMAIN:-eks-poc.au1.ping-lab.cloud}"
export TLS_CERT_ARN="${TLS_CERT_ARN:-arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012}"
export REGION="${REGION:-us-east-2}"

# Print out the values being used for each variable.
echo "Using SIZE: ${SIZE}"
echo "Using TENANT_NAME: ${TENANT_NAME}"
echo "Using TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Using TLS_CERT_ARN: ${TLS_CERT_ARN}"
echo "Using REGION: ${REGION}"
echo "Using CUSTOMER_REPO_URL: ${CUSTOMER_REPO_URL}"

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
TEMPLATES_HOME="${SCRIPT_HOME}/templates"

# Copy the shared cluster tools to the sandbox directory and substitute its
# variables first.
SANDBOX_DIR=/tmp/sandbox/k8s-configs
rm -rf "${SANDBOX_DIR}"
mkdir -p "${SANDBOX_DIR}"

cp -r "${TEMPLATES_HOME}/cluster-tools" "${SANDBOX_DIR}"
substitute_vars "${SANDBOX_DIR}"

# Next build up the directory for each environment.
ENVIRONMENTS='dev test staging prod'

PING_CLOUD_DIR="${SANDBOX_DIR}/ping-cloud"
mkdir -p "${PING_CLOUD_DIR}"

# These are exported as secrets, which are base64 encoded version of the user
# and key.
export PING_IDENTITY_DEVOPS_USER_BASE64=$(echo ${PING_IDENTITY_DEVOPS_USER} | base64)
export PING_IDENTITY_DEVOPS_KEY_BASE64=$(echo ${PING_IDENTITY_DEVOPS_KEY} | base64)

for ENV in ${ENVIRONMENTS}; do
  ENV_DIR="${PING_CLOUD_DIR}/${ENV}"
  cp -r "${TEMPLATES_HOME}"/ping-cloud/"${ENV}" "${ENV_DIR}"

  test "${ENV}" = 'prod' &&
    export KUSTOMIZE_BASE="${ENV}/${SIZE}" ||
    export KUSTOMIZE_BASE="${ENV}"

  # The k8s cluster name will be PingPoc-dev, PingPoc-test, etc. for the
  # different CDEs
  export CLUSTER_NAME=${TENANT_NAME}-${ENV}

  substitute_vars "${ENV_DIR}"
done

echo "Push k8s-configs directory under ${SANDBOX_DIR} into IaC repo into branches ${ENVIRONMENTS}"