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

file_names=$(curl https://github.com/kubernetes/kube-state-metrics/tree/v${KUBE_STATE_METRICS_VERSION}/examples/standard/ | jq -r '.payload.tree.items[].name')

files=()

while IFS= read -r line; do
  if [ "$line" != "index.html" ]; then
    files+=("$line")
  fi
done <<< "$file_names"

for file in "${files[@]}"; do
  curl "https://raw.githubusercontent.com/kubernetes/kube-state-metrics/v${KUBE_STATE_METRICS_VERSION}/examples/standard/$file" -o "$file"
done

echo "Kube State Metrics update complete, check your 'git diff' to see what changed"
