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
# Then, call this script with the debug option: ./deploy.sh debug
#
if test "${1}" != 'debug'; then
  echo "${KUBE_CA_PEM}" > "$(pwd)/kube.ca.pem"

  kubectl config set-cluster "${EKS_CLUSTER_NAME}" \
    --server="${KUBE_URL}" \
    --certificate-authority="$(pwd)/kube.ca.pem"

  kubectl config set-credentials aws \
    --exec-command aws-iam-authenticator \
    --exec-api-version client.authentication.k8s.io/v1alpha1 \
    --exec-arg=token \
    --exec-arg=-i --exec-arg="${EKS_CLUSTER_NAME}" \
    --exec-arg=-r --exec-arg="${AWS_ACCOUNT_ROLE_ARN}"

  kubectl config set-context "${EKS_CLUSTER_NAME}" \
    --cluster="${EKS_CLUSTER_NAME}" \
    --user=aws

  kubectl config use-context "${EKS_CLUSTER_NAME}"
fi

# Generate a self-signed cert for the tenant domain.
generate_tls_cert "${TENANT_DOMAIN}"

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
    ${REGION}
    ${TLS_CRT_BASE64}
    ${TLS_KEY_BASE64}' > ${DEPLOY_FILE}

echo "Deploy file contents:"
cat ${DEPLOY_FILE}

# Append the branch name to the ping-cloud namespace to make it unique. It's
# okay for the common cluster tools to just be deployed once to the cluster.
NAMESPACE=ping-cloud-${CI_COMMIT_REF_SLUG}
sed -i.bak -E "s/((namespace|name): )ping-cloud$/\1${NAMESPACE}/g" ${DEPLOY_FILE}

kubectl apply -f ${DEPLOY_FILE}

# Give each pod some time to initialize. The PF, PA apps deploy fast. PD is the
# long pole.
# FIXME: PD time will need to be adjusted based on number of replicas because
#        the ds servers are set up sequentially.
for deployment in $(kubectl get deployment,statefulset -n ${NAMESPACE} -o name); do
  [[ ${deployment} = 'statefulset.apps/ds' ]] && TIMEOUT=600s || TIMEOUT=120s
  kubectl rollout status --timeout ${TIMEOUT} ${deployment} -n ${NAMESPACE} -w
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