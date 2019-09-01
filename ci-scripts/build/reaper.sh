#!/bin/bash

EKS_CLUSTER_NAME="${1:-csg-test-cluster}"

# Set the kubectl context to the right cluster
kubectl config use-context ${EKS_CLUSTER_NAME}

# Get all namespaces with the desired namespace prefix
namespace_prefix="ping-cloud-"

ping_namespaces=$(kubectl get ns -o name |
  grep "${namespace_prefix}" |
  grep -v "${namespace_prefix}master" |
  cut -d/ -f2)

# Get all remote git branches except master. We'll leave the environment on
# master always running so it's available for quick testing.
git_branches=$(git ls-remote -q --heads |
  grep -v master |
  awk '{ print $2 }' |
  cut -d/ -f3)

echo "Namespaces in cluster ${EKS_CLUSTER_NAME} w/ prefix ${namespace_prefix}:"
echo "${ping_namespaces}"

echo "Git remote branches:"
echo "${git_branches}"

namespaces_to_delete=
for namespace in ${ping_namespaces}; do
  branch=$(echo ${namespace/#${namespace_prefix}})
  if [[ ! ${branch} =~ ${git_branches} ]]; then
    namespaces_to_delete="${namespaces_to_delete} ${namespace}"
  fi
done

if [[ ! -z ${namespaces_to_delete} ]]; then
  echo "Deleting namespaces:${namespaces_to_delete}"
  kubectl delete namespace${namespaces_to_delete} &
else
  echo "No namespaces to delete"
fi