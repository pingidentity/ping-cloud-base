#!/bin/bash
set -e

KARPENTER_VERSION="${1}"

USAGE="./update-karpenter.sh KARPENTER_VERSION

       example: ./update-karpenter.sh  v0.29.2"


if [[ ${KARPENTER_VERSION:0:1} == "v" ]]; then
    echo "Using Karpenter version: $KARPENTER_VERSION"
else
    echo "Usage: ${USAGE}"
    exit 1
fi

helm template karpenter oci://public.ecr.aws/karpenter/karpenter --version ${KARPENTER_VERSION} --namespace karpenter \
    --set settings.aws.defaultInstanceProfile=KarpenterInstanceProfile \
    --version ${KARPENTER_VERSION} > karpenter.yaml

wget -O karpenter.sh_provisioners.yaml https://raw.githubusercontent.com/aws/karpenter/${KARPENTER_VERSION}/pkg/apis/crds/karpenter.sh_provisioners.yaml
wget -O karpenter.k8s.aws_awsnodetemplates.yaml https://raw.githubusercontent.com/aws/karpenter/${KARPENTER_VERSION}/pkg/apis/crds/karpenter.k8s.aws_awsnodetemplates.yaml
wget -O karpenter.sh_machines.yaml https://raw.githubusercontent.com/aws/karpenter/${KARPENTER_VERSION}/pkg/apis/crds/karpenter.sh_machines.yaml
