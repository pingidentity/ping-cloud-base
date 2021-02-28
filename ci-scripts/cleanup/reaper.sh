#!/bin/bash

# Run this script periodically to clean up any environments that are still left behind on the CI-CD EKS cluster.

EKS_CLUSTER_NAME="${1:-ci-cd}"

# Set the kubectl context to the right cluster
kubectl config use-context ${EKS_CLUSTER_NAME}

# Get all namespaces with the desired namespace prefix
namespace_prefix="ping-cloud-"

# We'll leave the environment on
# master always running so it's available for quick testing.
ping_namespaces() {
  kubectl get ns -o name |
    sed -n "s|^namespace/${namespace_prefix}||p" |
    grep -v "master" |
    sort
}

git_branches() {
  git ls-remote -q --heads |
    awk '{ print $2 }' |
    sed "s|^refs/heads/||" |
    grep -v '^master$'
}

echo "Namespaces in cluster ${EKS_CLUSTER_NAME} w/ prefix ${namespace_prefix}:"
ping_namespaces

echo "Git remote branches:"
git_branches

comm -23 <(ping_namespaces) <(git_branches) |
  sed "s|^|${namespace_prefix}|" |
  xargs sh -c '
    echo "Deleting namespaces: $@"
    kubectl delete namespace "$@"
  ' ignore-me
