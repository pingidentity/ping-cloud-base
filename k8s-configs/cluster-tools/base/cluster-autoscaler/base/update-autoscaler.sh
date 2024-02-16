#!/bin/bash
set -e

USAGE="./update-autoscaler.sh CLUSTER_AUTOSCALER_VERSION"
REQ_PATH="k8s-configs/cluster-tools/base/cluster-autoscaler/base"

if [[ ! "$(pwd)" = *"${REQ_PATH}"* ]]; then
    echo "Script run source sanity check failed. Please only run this script in ${REQ_PATH}"
    exit 1
fi

if [[ $# != 1 ]]; then
    echo "Usage: ${USAGE}"
    exit 1
fi

CLUSTER_AUTOSCALER_VERSION="${1}"

curl "https://raw.githubusercontent.com/kubernetes/autoscaler/cluster-autoscaler-${CLUSTER_AUTOSCALER_VERSION}/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml" -o cluster-autoscaler.yaml

echo "cluster-autoscaler update complete, check your 'git diff' to see what changed"
