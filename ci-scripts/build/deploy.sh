#!/bin/bash
set -ex

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

#
# --- Local debugging ---
#
# Configure kubectl but only when not in debug mode, which may be used locally for testing.
# To test locally, export the following environment variables:
#
# export CI_PROJECT_DIR=~/sandbox/devops/ping-cloud-base (change this based on where your checkout tree is)
# export CI_COMMIT_REF_SLUG=test
# export TENANT_DOMAIN=ping-aws.com
# export AWS_DEFAULT_REGION=us-west-2
# export EKS_CLUSTER_NAME=ci-cd-cluster
#
# Then, call this script in this manner: SKIP_CONFIGURE_KUBE=true ./deploy.sh
#

# Configure kube config, unless skipped
configure_kube

export PING_IDENTITY_DEVOPS_USER_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_USER}")
export PING_IDENTITY_DEVOPS_KEY_BASE64=$(base64_no_newlines "${PING_IDENTITY_DEVOPS_KEY}")

# Deploy the configuration to Kubernetes
DEPLOY_FILE=/tmp/deploy.yaml
kustomize build ${CI_PROJECT_DIR}/test |
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
    ${LOG_ARCHIVE_URL}
    ${BACKUP_URL}' > ${DEPLOY_FILE}

log "Deploy file contents:"
cat ${DEPLOY_FILE}

# Append the branch name to the ping-cloud namespace to make it unique. It's
# okay for the common cluster tools to just be deployed once to the cluster.
sed -i.bak -E "s/((namespace|name): )ping-cloud$/\1${NAMESPACE}/g" ${DEPLOY_FILE}

kubectl apply -f ${DEPLOY_FILE}

# Give each pod some time to initialize. The PF, PA apps deploy fast. PD is the
# long pole and its timeout must be adjusted based on the number of replicas.
for DEPLOYMENT in $(kubectl get statefulset,deployment -n ${NAMESPACE} -o name); do
  NUM_REPLICAS=$(kubectl get ${DEPLOYMENT} -o jsonpath='{.spec.replicas}' -n ${NAMESPACE})
  TIMEOUT=$((${NUM_REPLICAS} * 600))
  time kubectl rollout status --timeout ${TIMEOUT}s ${DEPLOYMENT} -n ${NAMESPACE} -w
done

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