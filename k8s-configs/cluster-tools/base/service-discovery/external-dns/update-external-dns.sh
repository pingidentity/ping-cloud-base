#!/bin/bash
set -e

USAGE="./update-external-dns.sh EXTERNAL_DNS_VERSION"
REQ_PATH="k8s-configs/cluster-tools/base/service-discovery/external-dns"

if [[ ! "$(pwd)" = *"${REQ_PATH}"* ]]; then
    echo "Script run source sanity check failed. Please only run this script in ${REQ_PATH}"
    exit 1
fi

if [[ $# != 1 ]]; then
    echo "Usage: ${USAGE}"
    exit 1
fi

EXTERNAL_DNS_VERSION="${1}"
EXTERNAL_DNS_RAW_URL="https://raw.githubusercontent.com/kubernetes-sigs/external-dns"

curl "${EXTERNAL_DNS_RAW_URL}/${EXTERNAL_DNS_VERSION}/kustomize/external-dns-clusterrole.yaml" -o clusterrole.yaml
curl "${EXTERNAL_DNS_RAW_URL}/${EXTERNAL_DNS_VERSION}/kustomize/external-dns-clusterrolebinding.yaml" -o clusterrolebinding.yaml
curl "${EXTERNAL_DNS_RAW_URL}/${EXTERNAL_DNS_VERSION}/kustomize/external-dns-deployment.yaml" -o deployment.yaml
curl "${EXTERNAL_DNS_RAW_URL}/${EXTERNAL_DNS_VERSION}/kustomize/external-dns-serviceaccount.yaml" -o serviceaccount.yaml

echo "external-dns update complete, check your 'git diff' to see what changed"