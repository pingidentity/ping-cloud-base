#!/bin/bash
set -e

USAGE="./update-argo.sh ARGO_VERSION"
REQ_PATH="k8s-configs/cluster-tools/base/git-ops/argo/base"

if [[ ! "$(pwd)" = *"${REQ_PATH}"* ]]; then
    echo "Script run source sanity check failed. Please only run this script in ${REQ_PATH}"
    exit 1
fi

if [[ $# != 1 ]]; then
    echo "Usage: ${USAGE}"
    exit 1
fi

ARGO_VERSION="${1}"

curl "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGO_VERSION}/manifests/install.yaml" -o install.yaml

echo "ArgoCD update complete, check your 'git diff' to see what changed"
