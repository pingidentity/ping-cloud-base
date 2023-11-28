#!/bin/bash
set -e

USAGE="./update-volume-autoscaler.sh VOLUME_AUTOSCALER_VERSION"
REQ_PATH="k8s-configs/cluster-tools/base/monitoring/prometheus/volume-autoscaler"

if [[ ! "$(pwd)" = *"${REQ_PATH}"* ]]; then
    echo "Script run source sanity check failed. Please only run this script in ${REQ_PATH}"
    exit 1
fi

if [[ $# != 1 ]]; then
    echo "Usage: ${USAGE}"
    exit 1
fi

VOLUME_AUTOSCALER_VERSION="${1}"

curl "https://devops-nirvana.s3.amazonaws.com/volume-autoscaler/volume-autoscaler-${VOLUME_AUTOSCALER_VERSION}.yaml" -o install-volume-autoscaler.yaml

echo "Kube Volume Autoscaler update complete, check your 'git diff' to see what changed"
