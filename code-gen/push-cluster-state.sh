#!/bin/bash

# WARNING: This script must only be used to seed the initial cluster state. It is destructive and will replace the
# contents of the remote branches corresponding to the different Customer Deployment Environments with new state.

# NOTE: This script must be run from the root of the cluster state repo clone directory. It acts on the following
# environment variables, if set.
#
#   GENERATED_CODE_DIR -> The TARGET_DIR of generate-cluster-state.sh. Defaults to '/tmp/sandbox'. if unset.
#   ENVIRONMENTS -> A space-separated list of environments. Defaults to 'dev test stage prod', if unset. If provided,
#   it must contain all or a subset of the environments currently created by the generate-cluster-state.sh script -
#   dev, test, stage, prod.
#   PUSH_RETRY_COUNT -> The number to times to try pushing to the cluster state repo with a 2s sleep between each
#   attempt to avoid IAM permission to repo sync issue.

########################################################################################################################
# Organizes the Kubernetes configuration files to push into the cluster state repo for a specific Customer Deployment
# Environment (CDE).
#
# Arguments
#   ${1} -> The directory where cluster state code was generated, i.e. the TARGET_DIR to generate-cluster-state.sh.
#   ${2} -> The environment.
#   ${3} -> The target directory into which to organize the code to push for the environment.
########################################################################################################################
organize_code_for_environment() {
  GENERATED_CODE_DIR="${1}"
  ENV="${2}"
  ENV_CODE_DIR="${3}"
  ALL_ENVIRONMENTS=${4}

  cp -pr "${GENERATED_CODE_DIR}"/cluster-state/. "${ENV_CODE_DIR}"
  K8S_DIR="${ENV_CODE_DIR}"/k8s-configs

  rm -rf "${K8S_DIR:?}"/*
  cp -pr "${GENERATED_CODE_DIR}"/cluster-state/k8s-configs/"${ENV}"/. "${K8S_DIR}"
}

########################################################################################################################
# Attempt to push to the provided branch on the cluster state repo up to the specified number of retries.
#
# Arguments
#   ${1} -> Retry count.
#   ${2} -> The git branch to push to on origin.
########################################################################################################################
push_with_retries() {
  RETRY_COUNT=${1}
  GIT_BRANCH=${2}

  for ATTEMPT in $(seq 1 "${RETRY_COUNT}"); do
    echo "Attempt #${ATTEMPT} pushing to server"
    git push --set-upstream origin "${GIT_BRANCH}" && break
    sleep 2s
  done
}

### Script start ###
ALL_ENVIRONMENTS='dev test stage prod'
ENVIRONMENTS="${ENVIRONMENTS:-${ALL_ENVIRONMENTS}}"
GENERATED_CODE_DIR="${GENERATED_CODE_DIR:-/tmp/sandbox}"
PUSH_RETRY_COUNT="${PUSH_RETRY_COUNT:-30}"

for ENV in ${ENVIRONMENTS}; do
  echo "Processing ${ENV}"

  ENV_CODE_DIR=$(mktemp -d)
  organize_code_for_environment "${GENERATED_CODE_DIR}" "${ENV}" "${ENV_CODE_DIR}"

  if test "${ENV}" != 'prod'; then
    GIT_BRANCH="${ENV}"
    # Check if the branch exists on remote. If so, switch to it and pull the latest code from it.
    if git ls-remote --quiet --heads | grep "${GIT_BRANCH}" &> /dev/null; then
      git checkout "${GIT_BRANCH}"
      git pull
    else
      # Check if the branch exists locally. If so, switch to master first and then delete it.
      if git rev-parse --verify "${GIT_BRANCH}"; then
        git checkout master
        git branch -D "${GIT_BRANCH}"
      fi
      git checkout -b "${GIT_BRANCH}"
    fi
  else
    GIT_BRANCH=master
    git checkout "${GIT_BRANCH}"
    git pull
  fi

  rm -rf ./*
  cp -pr "${ENV_CODE_DIR}"/. .

  git add .
  git commit -m 'Initial commit'
  push_with_retries "${PUSH_RETRY_COUNT}" "${GIT_BRANCH}"

  echo
  echo ---
  echo
done