#!/bin/bash
set -e

USAGE="./update-metrics-server.sh METRICS_SERVER_VERSION"
REQ_PATH="k8s-configs/cluster-tools/base/metrics/metrics-server/base"

if [[ ! "$(pwd)" = *"${REQ_PATH}"* ]]; then
    echo "Script run source sanity check failed. Please only run this script in ${REQ_PATH}"
    exit 1
fi

if [[ $# != 1 ]]; then
    echo "Usage: ${USAGE}"
    exit 1
fi

METRICS_SERVER_VERSION="${1}"

file_names=$(curl https://github.com/kubernetes-sigs/metrics-server/tree/v${METRICS_SERVER_VERSION}/manifests/base/ | jq -r '.payload.tree.items[].name')

files=()

while IFS= read -r line; do
  if [ "$line" != "index.html" ]; then
    files+=("$line")
  fi
done <<< "$file_names"

for file in "${files[@]}"; do
  curl "https://raw.githubusercontent.com/kubernetes-sigs/metrics-server/v${METRICS_SERVER_VERSION}/manifests/base/$file" -o "$file"
done

sed "s/\(newTag: \)[^ ]*/\1v${METRICS_SERVER_VERSION}/" ../kustomization.yaml > temp_file && mv temp_file ../kustomization.yaml

echo "Metrics Server update complete, check your 'git diff' to see what changed"
