#!/bin/bash
set -ex

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

pushd "${PROJECT_DIR}"

# Configure kube config, unless skipped
configure_kube

NEW_RELIC_LICENSE_KEY=${NEW_RELIC_LICENSE_KEY:-unused}

export PING_IDENTITY_DEVOPS_USER_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_USER}")
export PING_IDENTITY_DEVOPS_KEY_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_KEY}")
export NEW_RELIC_LICENSE_KEY_BASE64=$(base64_no_newlines "${NEW_RELIC_LICENSE_KEY}")

# Deploy the configuration to Kubernetes
DEPLOY_FILE=/tmp/deploy.yaml
build_dev_deploy_file "${DEPLOY_FILE}"

kubectl apply -f "${DEPLOY_FILE}"

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

PD_REPLICA='statefulset.apps/pingdirectory'
OTHER_PING_APP_REPLICAS='statefulset.apps/pingfederate statefulset.apps/pingaccess statefulset.apps/pingaccess-was'

NUM_PD_REPLICAS=$(kubectl get "${PD_REPLICA}" -o jsonpath='{.spec.replicas}' -n "${NAMESPACE}")
PD_TIMEOUT_SECONDS=$((NUM_PD_REPLICAS * 900))
DEPENDENT_TIMEOUT_SECONDS=300

echo "Waiting for rollout of ${PD_REPLICA} with a timeout of ${PD_TIMEOUT_SECONDS} seconds"
time kubectl rollout status "${PD_REPLICA}" --timeout "${PD_TIMEOUT_SECONDS}s" -n "${NAMESPACE}" -w

for DEPENDENT_REPLICA in ${OTHER_PING_APP_REPLICAS}; do
  echo "Waiting for rollout of ${DEPENDENT_REPLICA} with a timeout of ${DEPENDENT_TIMEOUT_SECONDS} seconds"
  time kubectl rollout status "${DEPENDENT_REPLICA}" --timeout "${DEPENDENT_TIMEOUT_SECONDS}s" -n "${NAMESPACE}" -w
done

# Print out the ingress objects for logs and the ping stack
echo
echo '--- Ingress URLs ---'
kubectl get ingress -A

# Print out the pingdirectory hostname
echo
echo '--- LDAP hostname ---'
kubectl get svc pingdirectory-admin -n "${NAMESPACE}" \
  -o jsonpath='{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}'

# Print out the  pods for the ping stack
echo
echo
echo '--- Pod status ---'
kubectl get pods -n "${NAMESPACE}"

popd  > /dev/null 2>&1
