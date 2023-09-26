#!/bin/bash
set -e

USAGE="./update-kube-state-metrics.sh KUBE_STATE_METRICS_VERSION"
REQ_PATH="k8s-configs/cluster-tools/base/metrics/kube-state-metrics/base"

if [[ ! "$(pwd)" = *"${REQ_PATH}"* ]]; then
    echo "Script run source sanity check failed. Please only run this script in ${REQ_PATH}"
    exit 1
fi

if [[ $# != 1 ]]; then
    echo "Usage: ${USAGE}"
    exit 1
fi

KUBE_STATE_METRICS_VERSION="${1}"

curl "https://raw.githubusercontent.com/kubernetes/kube-state-metrics/v${KUBE_STATE_METRICS_VERSION}/examples/standard/cluster-role-binding.yaml" -o cluster-role-binding.yaml
curl "https://raw.githubusercontent.com/kubernetes/kube-state-metrics/v${KUBE_STATE_METRICS_VERSION}/examples/standard/cluster-role.yaml" -o cluster-role.yaml
curl "https://raw.githubusercontent.com/kubernetes/kube-state-metrics/v${KUBE_STATE_METRICS_VERSION}/examples/standard/deployment.yaml" -o deployment.yaml
curl "https://raw.githubusercontent.com/kubernetes/kube-state-metrics/v${KUBE_STATE_METRICS_VERSION}/examples/standard/service-account.yaml" -o service-account.yaml
curl "https://raw.githubusercontent.com/kubernetes/kube-state-metrics/v${KUBE_STATE_METRICS_VERSION}/examples/standard/service.yaml" -o service.yaml


echo "Kube State Metrics update complete, check your 'git diff' to see what changed"
