#!/bin/bash
set -ex

# Configure kubectl
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

# Deploy the configuration to Kubernetes
DEPLOY_FILE=/tmp/deploy.yaml
kustomize build ${CI_PROJECT_DIR}/test | envsubst > ${DEPLOY_FILE}

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

# Print out the ingress objects for the ping stack
kubectl get ingress -n ${NAMESPACE}