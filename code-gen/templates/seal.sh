#!/bin/bash

##### ----- READ BEFORE RUNNING THE SCRIPT ----- #####

# The following script shows how to seal all the secrets used by ping apps and their supporting cluster tools.
# It requires kustomize and kubeseal to be installed.

# It is recommended that all (instead of a subset) of the secrets be sealed at the same time. This ensures that they
# are all encrypted with the same sealing key. After sealing the secrets, make sure to save off the Bitnami service's
# master key using PingCloud docs.

# Before running this script, populate all the required secrets in the ping-cloud and cluster-tools secret.yaml files.
# A copy of the original contents of the secrets.yaml file is available in both the ping-cloud and cluster-tools
# directories. The script intentionally does not replace any files in the cluster state repo because it can be
# destructive. Instead, it prints out the steps required to seal secrets for the DevOps engineer to apply manually.


SCRIPT_DIR=$(cd $(dirname "${0}"); pwd)
pushd "${SCRIPT_DIR}" &> /dev/null

########################################################################################################################
# Verify that the provided binaries are available.
#
# Arguments
#   ${*} -> The list of required binaries.
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

####################
#   Start script   #
####################

# Check for required binaries.
check_binaries "kustomize" "kubeseal"
HAS_REQUIRED_TOOLS=${?}
test ${HAS_REQUIRED_TOOLS} -ne 0 && exit 1

echo "-----------------------------------------------------------------------------------------------------------------"
echo "Read the 'READ BEFORE RUNNING THE SCRIPT' section at the top of this script"
echo "-----------------------------------------------------------------------------------------------------------------"

OUT_DIR=$(mktemp -d)
kustomize build --output "${OUT_DIR}"

YAML_FILES=$(find "${OUT_DIR}" -type f | xargs grep -rl 'kind: Secret')
if test -z "${YAML_FILES}"; then
  echo "No secrets found to seal"
  exit 0
fi

CERT_FILE=${1}

# If the certificate file is not provided, try to get the certificate from the Bitnami sealed secret service.
# The sealed-secrets controller must be running in the cluster, and it should be possible to access the Kubernetes
# API server for this to work.
if test -z "${CERT_FILE}"; then
  CERT_FILE=$(mktemp)
  echo "Fetching the sealed secret certificate from the cluster"
  kubeseal --fetch-cert --controller-namespace kube-system > "${CERT_FILE}"
fi

echo "-----------------------------------------------------------------------------------------------------------------"
echo "WARNING!!! Ensure that ${CERT_FILE} contains the public key of the Bitnami sealed secret service running in your "
echo "cluster. It may be obtained by running the following command on the management node:"
echo
echo "kubeseal --fetch-cert --controller-namespace kube-system"
echo "-----------------------------------------------------------------------------------------------------------------"
echo "Using certificate file ${CERT_FILE} for encrypting secrets"

SEALED_SECRETS_FILE=/tmp/sealed-secrets.yaml
rm -f "${SEALED_SECRETS_FILE}"

PING_SECRETS_FILE=/tmp/ping-secrets.yaml
rm -f "${PING_SECRETS_FILE}"

CLUSTER_SECRETS_FILE=/tmp/cluster-secrets.yaml
rm -f "${CLUSTER_SECRETS_FILE}"

for FILE in ${YAML_FILES}; do
  NAME=$(grep 'name:' "${FILE}" | cut -d: -f2 | tr -d '[:space:]')
  NAMESPACE=$(grep 'namespace:' "${FILE}" | cut -d: -f2 | tr -d '[:space:]')

  # Append/add a patch to delete the secret to the patches file.
  test "${NAMESPACE#ping-cloud}" != "${NAMESPACE}" &&
      PATCH_FILE="${PING_SECRETS_FILE}" ||
      PATCH_FILE="${CLUSTER_SECRETS_FILE}"

  cat >> "${PATCH_FILE}" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${NAME}
  namespace: ${NAMESPACE}
\$patch: delete

---

EOF

  # Only seal secrets that have data in them.
  if grep '^data' "${FILE}" &> /dev/null; then
    echo "Creating sealed secret for \"${NAMESPACE}:${NAME}\""

    # Append the sealed secret to the sealed secrets file.
    ! test -f "${SEALED_SECRETS_FILE}" && printf "\n\n" > "${SEALED_SECRETS_FILE}"
    kubeseal --cert "${CERT_FILE}" -o yaml < "${FILE}" >> "${SEALED_SECRETS_FILE}"
    echo --- >> "${SEALED_SECRETS_FILE}"

    # Replace ping-cloud-* namespace to just ping-cloud because it is the default in the kustomization base.
    echo -n "${NAMESPACE}" | grep '^ping-cloud' &> /dev/null && NAMESPACE=ping-cloud
  else
    echo "Not creating sealed secret for \"${NAMESPACE}:${NAME}\" because it doesn't have any data"
  fi
done

echo
echo '------------------------'
echo '|  Next steps to take  |'
echo '------------------------'
echo "- Run the following commands:"
echo "      test -f ${CLUSTER_SECRETS_FILE} && cp ${CLUSTER_SECRETS_FILE} cluster-tools/secrets.yaml"
echo "      test -f ${PING_SECRETS_FILE} && cp ${PING_SECRETS_FILE} ping-cloud/secrets.yaml"
echo "      test -f ${SEALED_SECRETS_FILE} && cp ${SEALED_SECRETS_FILE} sealed-secrets.yaml"
echo "      kustomize build > /tmp/deploy.yaml"
echo "      grep 'kind: Secret' /tmp/deploy.yaml # should not have any hits"
echo "      grep 'kind: SealedSecret' /tmp/deploy.yaml # should have hits"
echo "- Push all modified files into the cluster state repo"
echo "- Run this script for each CDE branch in the order - dev, test, stage, prod, if not already done"
echo "- IMPORTANT: create a backup of the Bitnami service's master key using PingCloud docs"

popd &> /dev/null