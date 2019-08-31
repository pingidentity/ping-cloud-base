#!/bin/sh
set -ex

# Deploy to Kubernetes
kustomize build ${CI_PROJECT_DIR}/test | envsubst | kubectl apply -f -

# Give each pod 5 minutes to initialize. The PF, PA apps deploy fast. PD is the
# long pole.
for deployment in $(kubectl get deployment,statefulset -n ping-cloud -o name); do
  kubectl rollout status --timeout 300s ${deployment} -n ping-cloud -w
done

# Print out the ingress object for the ping stack
kubectl get ingress -n ping-cloud