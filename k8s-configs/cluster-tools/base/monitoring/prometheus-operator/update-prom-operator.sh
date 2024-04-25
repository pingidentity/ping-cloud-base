#!/bin/bash
set -e

OPERATOR_VERSION="${1}"

USAGE="./update-prom-operator.sh OPERATOR_VERSION

       example: ./update-prom-operator.sh v0.73.0"

if [[ ${OPERATOR_VERSION:0:1} == "v" ]]; then
    echo "Using Prometheus operator version: $OPERATOR_VERSION"
else
    echo "Usage: ${USAGE}"
    exit 1
fi

# Get CRDs
curl -sL https://github.com/prometheus-operator/prometheus-operator/releases/download/${OPERATOR_VERSION}/stripped-down-crds.yaml \
      -o ./base/crds.yaml

# Get controller resources
curl -sL https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/${OPERATOR_VERSION}/bundle.yaml \
      | yq -r '.| select(.kind != "CustomResourceDefinition")' > controller/operator.yaml

echo "Please check $(pwd)/controller/operator.yaml to cleanup leftover '---'"