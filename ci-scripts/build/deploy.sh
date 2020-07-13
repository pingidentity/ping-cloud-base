#!/bin/bash
set -ex

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

# Configure kube config, unless skipped
configure_kube

export PING_IDENTITY_DEVOPS_USER_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_USER}")
export PING_IDENTITY_DEVOPS_KEY_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_KEY}")

# Set the cluster-type to "parent" - we only have one CI/CD cluster.
DEV_CLUSTER_STATE_DIR="${PROJECT_DIR}"/test

# Deploy the configuration to Kubernetes
DEPLOY_FILE=/tmp/deploy.yaml
kustomize build "${DEV_CLUSTER_STATE_DIR}" |
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
    ${PD_PRIMARY_PUBLIC_HOSTNAME}
    ${PF_ADMIN_PUBLIC_HOSTNAME}
    ${PA_ADMIN_PUBLIC_HOSTNAME}
    ${PA_CLUSTER_PUBLIC_HOSTNAME}
    ${ARTIFACT_REPO_URL}
    ${PING_ARTIFACT_REPO_URL}
    ${LOG_ARCHIVE_URL}
    ${BACKUP_URL}
    ${CLUSTER_BUCKET_NAME}' > "${DEPLOY_FILE}"

log "Deploy file contents:"
cat "${DEPLOY_FILE}"

# Append the branch name to the ping-cloud namespace to make it unique. It's
# okay for the common cluster tools to just be deployed once to the cluster.
sed -i.bak -E "s/((namespace|name): )ping-cloud$/\1${NAMESPACE}/g" "${DEPLOY_FILE}"

kubectl apply -f "${DEPLOY_FILE}"

# A PingDirectory pod can take up to 15 minutes to deploy in the CI/CD cluster. There are two sets of dependencies
# today from:
#
#     1. PA engine -> PA admin -> PF admin -> PD
#     2. PF engine -> PF admin -> PD
#
# So checking the rollout status of the end dependencies should be enough after PD is rolled out. We'll give each 2.5
# minutes after PD is ready. This should be more than enough time because as soon as pingdirectory-0 is ready, the
# rollout of the others will begin, and they don't take nearly as much time as a single PD server. So the entire Ping
# stack must be rolled out in no more than (15 * num of PD replicas + 2.5 * number of end dependents) minutes.

PD_REPLICA='statefulset.apps/pingdirectory'
DEPENDENT_REPLICAS='statefulset.apps/pingfederate statefulset.apps/pingaccess'

NUM_PD_REPLICAS=$(kubectl get "${PD_REPLICA}" -o jsonpath='{.spec.replicas}' -n "${NAMESPACE}")
PD_TIMEOUT_SECONDS=$((NUM_PD_REPLICAS * 900))
DEPENDENT_TIMEOUT_SECONDS=300

echo "Waiting for rollout of ${PD_REPLICA} with a timeout of ${PD_TIMEOUT_SECONDS} seconds"
time kubectl rollout status "${PD_REPLICA}" --timeout "${PD_TIMEOUT_SECONDS}s" -n "${NAMESPACE}" -w

for DEPENDENT_REPLICA in ${DEPENDENT_REPLICAS}; do
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
kubectl get svc ingress-nginx -n ingress-nginx-private \
  -o jsonpath='{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}'

# Print out the  pods for the ping stack
echo
echo
echo '--- Pod status ---'
kubectl get pods -n "${NAMESPACE}"
