#!/bin/bash
set -x

VARS='${PING_IDENTITY_DEVOPS_USER}
${PING_IDENTITY_DEVOPS_KEY}
${SIZE}
${TENANT_DOMAIN}
${TLS_CERT_ARN}
${REGION}
${CLUSTER_NAME}
${CUSTOMER_REPO_URL}
${KUSTOMIZE_BASE}'

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

check_env_vars "PING_IDENTITY_DEVOPS_USER" "PING_IDENTITY_DEVOPS_KEY"
if test ${?} -ne 0; then
  exit 1
fi

export SIZE="${SIZE:-small}"
export TENANT_DOMAIN="${TENANT_DOMAIN:-eks-poc.au1.ping-lab.cloud}"
export TLS_CERT_ARN="${TLS_CERT_ARN:-arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012}"
export REGION="${REGION:-us-east-2}"
export CLUSTER_NAME="${CLUSTER_NAME:-PingPOC}"

echo "Using SIZE: ${SIZE}"
echo "Using TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Using TLS_CERT_ARN: ${TLS_CERT_ARN}"
echo "Using REGION: ${REGION}"
echo "Using CLUSTER_NAME: ${CLUSTER_NAME}"
echo "Using CUSTOMER_REPO_URL: ${CUSTOMER_REPO_URL}"

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
TEMPLATES_HOME="${SCRIPT_HOME}/templates"

SANDBOX_DIR=/tmp/sandbox/k8s-configs
rm -rf "${SANDBOX_DIR}"
mkdir -p "${SANDBOX_DIR}"

ENVIRONMENTS='dev test staging prod'

cp -r "${TEMPLATES_HOME}/cluster-tools" "${SANDBOX_DIR}"
substitute_vars "${SANDBOX_DIR}"

PING_CLOUD_DIR="${SANDBOX_DIR}/ping-cloud"
mkdir -p "${PING_CLOUD_DIR}"

for ENV in ${ENVIRONMENTS}; do
  ENV_DIR="${PING_CLOUD_DIR}/${ENV}"
  cp -r "${TEMPLATES_HOME}"/ping-cloud/"${ENV}" "${ENV_DIR}"

  test "${ENV}" = 'prod' &&
    export KUSTOMIZE_BASE="${ENV}/${SIZE}" ||
    export KUSTOMIZE_BASE="${ENV}"

  substitute_vars "${ENV_DIR}"
done