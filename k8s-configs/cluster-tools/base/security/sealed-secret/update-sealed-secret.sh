#!/bin/bash
set -e

USAGE="./update-sealed-secret.sh SEALED_SECRET_VERSION"
REQ_PATH="k8s-configs/cluster-tools/base/security/sealed-secret"

if [[ ! "$(pwd)" = *"${REQ_PATH}"* ]]; then
    echo "Script run source sanity check failed. Please only run this script in ${REQ_PATH}"
    exit 1
fi

if [[ $# != 1 ]]; then
    echo "Usage: ${USAGE}"
    exit 1
fi

SEALED_SECRET_VERSION="${1}"

wget -q "https://github.com/bitnami-labs/sealed-secrets/releases/download/${SEALED_SECRET_VERSION}/controller.yaml" -O controller.yaml

echo "sealed-secret update complete, check your 'git diff' to see what changed"
