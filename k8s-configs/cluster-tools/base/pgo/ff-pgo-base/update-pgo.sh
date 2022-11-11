#!/bin/bash
set -e

if [[ ! "$(pwd)" =~ "k8s-configs/cluster-tools/base/pgo/ff-pgo-base" ]]; then
    echo "Script run source sanity check failed. Please only run this script in k8s-configs/cluster-tools/base/pgo/base"
    exit 1
fi

# TODO: take a SHA to pull a specific version of the example repo

source ../../../../../utils.sh

# Update the PGO CRDs, other resources based on the github.com/CrunchyData/postgres-operator-examples repo.
# NOTE: only run this script in the k8s-configs/cluster-tools/base/pgo/base directory
cur_date=$(date -I seconds)
tmp_dir="/tmp/pgo/${cur_date}"
example_repo="postgres-operator-examples"
repo_dir="${tmp_dir}/${example_repo}"
repo_dir_kustomize="${repo_dir}/kustomize/install"

log "Creating tmp dir - ${tmp_dir}"
mkdir "${tmp_dir}"

git clone "https://github.com/CrunchyData/${example_repo}" "${tmp_dir}/${example_repo}"

# Remove the singlenamespace dir, we don't use it
rm -rf "${repo_dir_kustomize}/singlenamespace"

# Copy the massaged repo directory to this directory
rsync -rv "${repo_dir_kustomize}/" .

log "PGO update complete, check your 'git diff' to see what changed"