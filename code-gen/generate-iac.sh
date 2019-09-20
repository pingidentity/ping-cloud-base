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