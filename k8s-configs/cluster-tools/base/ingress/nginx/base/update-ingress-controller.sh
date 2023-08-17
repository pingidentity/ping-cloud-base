#!/bin/bash
set -e

USAGE="./update-ingress-controller.sh INGRESS_NGINX_VERSION"
REQ_PATH="k8s-configs/cluster-tools/base/ingress/nginx/base"

if [[ ! "$(pwd)" = *"${REQ_PATH}"* ]]; then
    echo "Script run source sanity check failed. Please only run this script in ${REQ_PATH}"
    exit 1
fi

if [[ $# != 1 ]]; then
    echo "Usage: ${USAGE}"
    exit 1
fi

INGRESS_NGINX_VERSION="${1}"

curl "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_NGINX_VERSION}/deploy/static/provider/baremetal/deploy.yaml" -o ingress-controller.yaml

echo "ingress-nginx update complete, check your 'git diff' to see what changed"