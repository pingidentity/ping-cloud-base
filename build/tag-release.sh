#!/bin/bash -e

########################################################################################################################
# Prints script usage
########################################################################################################################
usage() {
  echo "Usage: ${0} SOURCE_REF TARGET_REF [REF_TYPE]"
  echo "  where"
  echo "    SOURCE_REF => source ref from where to create the target ref, e.g. v1.14-release-branch"
  echo "    TARGET_REF => the target ref, e.g. v1.15-release-branch, v1.15.0.0_RC1"
  echo "    REF_TYPE => the target ref type - tag or branch"
}

########################################################################################################################
# Gets a product image's repo
# Arguments:
#   ${1} -> the product to search for (Ex: "pingaccess")
########################################################################################################################
get_image_repo() {
  local image=${1}

  repo=$(git grep -h "image: public.ecr.aws/r2h3l6e4/.*/${image}" | head -n 1)
  repo=$(echo "${repo}" | sed "s|image: public.ecr.aws/r2h3l6e4/||g")
  repo="${repo%"/${image}"*}"

  echo "${repo}"
}

########################################################################################################################
# Replaces the current version references in the source ref with the target ref in all the necessary places. Then,
# commits the changes into the target ref(branch or tag). Must be in the ping-cloud-base directory for it to work
# correctly.
#
# Arguments:
#   ${1} -> The source ref
#   ${2} -> The target ref
#   ${3} -> The ref type- tag or branch
########################################################################################################################
replace_and_commit() {
  local source_value=${1}
  local target_value=${2}
  local ref_value=${3}
  local source_dash_branch
  local target_dash_branch

  local image_map=(
    "pingaccess"
    "pingaccess-was"
    "pingfederate"
    "pingdirectory"
    "pingdelegator"
    "pingcentral"
    "pingdatasync"
    "bootstrap"
    "p14c-integration"
    "metadata"
    "healthcheck"
    "ansible-beluga"
    "logstash"
    "grafana"
    "enrichment-bootstrap"
    "prometheus-json-exporter"
    "prometheus-job-exporter"
    "newrelic-tags-exporter"
    "nri-kubernetes"
    "robot-framework"
    "sigsci-nginx-ingress-controller"
    "sigsci-agent"
  )

  for image in ${image_map[@]}; do
    image_tag_var="$(echo "${image}" | tr '-' '_' | tr '[:lower:]' '[:upper:]')_IMAGE_TAG"
    image_repo=$(get_image_repo ${image} | xargs)

    echo ---
    echo "Changing values for ${image_repo}/${image} in expected files"

    if test "${ref_value}" = 'tag'; then
      # If tag, search registry for latest image version
      target_image=$(python3 "${PWD_DIR}"/python/src/get_latest_image.py "${image_repo}/${image}" ${target_value})
    else
      # If branch, use target value
      target_image="${target_value}"
    fi

    # update base env vars
    grep_var "${image_tag_var}" "${source_value}" "${target_image}"

    # update k8s yaml files
    grep_yaml "${image}" "${source_value}" "${target_image}" "${ref_value}"
  done

# Getting source and tagret branch for dashboards repo. Current development release branch becomes $release-dev-branch
# and current tag becomes $release-release-branch. E.g. v1.17-release-branch becomes v1.17-dev-branch and v1.17.0 becomes
# v1.17-release-branch for dashboard repo
# Regex will work until release branch will be v#.##-release-branch and tag will be v#.##.* since it replaces one of two
# expressions:
# 1) ^(v[[:digit:]]+\.[[:digit:]]+)-release-branch.*
# 2) ^(v[[:digit:]]+\.[[:digit:]]{2})(\..*)
# Round brackets here used for grouping, so sed can replace only needed group.
# At perl regex these expressions should be:
# 1) ^(v\d+\.\d+)-release-branch.*
# 2) ^(v\d+\.\d{2})(\..*)
  source_dash_branch=$(echo "${source_value}"|sed -r 's/^(v[[:digit:]]+\.[[:digit:]]+)-release-branch.*/\1-dev-branch/;s/^(v[[:digit:]]+\.[[:digit:]]{2})(\..*)/\1-release-branch/g')
  target_dash_branch=$(echo "${target_value}"|sed -r 's/^(v[[:digit:]]+\.[[:digit:]]+)-release-branch.*/\1-dev-branch/;s/^(v[[:digit:]]+\.[[:digit:]]{2})(\..*)/\1-release-branch/g')

  grep_var "DASH_REPO_BRANCH" "${source_dash_branch}" "${target_dash_branch}"

  echo ---
  echo "Committing changes for new ${ref_value} ${target_value}"
  git add .
  git commit -m "[skip pipeline] - creating new ${ref_value} ${target_value}"
}

grep_var() {
  local var=${1}
  local source_value=${2}
  local target_value=${3}

  echo "Changing ${var}=${source_value} -> ${var}=${target_value} in base env vars"

  git grep -l "^${var}=${source_value}" | xargs sed -i.bak "s/^\(${var}=\)${source_value}$/\1${target_value}/g"
}

grep_yaml() {
  local var=${1}
  local source_value=${2}
  local target_value=${3}
  local ref_value=${4}

  local dev_ecr_path="image: public.ecr.aws/r2h3l6e4/.*/${var}/dev"

  echo "Changing ${var}:${source_value} -> ${var}:${target_value} in k8s yaml files"

  cd "${SANDBOX}"/ping-cloud-base/k8s-configs
  git grep -l "${dev_ecr_path}:${source_value}" | xargs sed -i.bak "s/${var}\/dev:${source_value}/${var}\/dev:${target_value}/g"

  if test "${ref_value}" = 'tag'; then
    # update the ecr path to prod from dev
    git grep -l "${dev_ecr_path}" | xargs sed -i.bak "s/${var}\/dev:/${var}:/g"
  fi

  cd "${SANDBOX}"/ping-cloud-base/
}

########################################################################################################################
# Performs a 'grep' on each file within the repo searching for dev image paths.
#
# Returns
#   non-zero on failure.
########################################################################################################################
verify_k8s_image_repositories() {
  search_dev_image=$(git grep -h "image: public.ecr.aws/r2h3l6e4/." | grep -v "search_dev_image" | grep "/dev:" | xargs)
  echo "---"

  if test -z "$search_dev_image"; then
    echo "Verified all dev image paths removed"
  else
    echo "Error: The below dev image paths still exist"
    echo "$search_dev_image"
    return 1
  fi
}

###########################################################################################################################
# Verifies the 'REF_TYPE' if its a 'tag' or 'branch'.
#
# (1) -->if the 'REF_TYPE' is a 'branch' then --> creates new branch and adds new changes on the new branch as follows -
#
# updates 'SERVER_PROFILE_BRANCH' variable with target branch name (v*.*-release-branch)
# updates 'base/env_vars' image tags with target branch name (v*.*-release-branch-latest)
# updates yaml files docker images with target branch name (v*.*-release-branch-latest)
#
# eg: `build/tag-release.sh v1.14-release-branch v1.15-release-branch branch`
#
# (2) -->if the 'REF_TYPE' is a 'tag' then --> adds new changes as follows and then creates a new tag -
#
# updates 'SERVER_PROFILE_BRANCH' variable with target tag name (v*.*.*.*_RC1 or v*.*.*.*)
# updates 'base/env_vars' image tags with latest RC or final image version (v*.*.*.*_RC1 or v*.*.*.*)
# updates yaml files docker images target tag name with latest RC or final image version (v*.*.*.*_RC1 or v*.*.*.*)
# updates the ecr path to 'prod' from 'dev'
#
# eg: `build/tag-release.sh v1.14-release-branch v1.14.0.0_RC1 tag`
# eg: `build/tag-release.sh v1.14-release-branch v1.14.0.0 tag`
#
###########################################################################################################################

SOURCE_REF=${1}
TARGET_REF=${2}
REF_TYPE=${3}

if test -z "${SOURCE_REF}" || test -z "${TARGET_REF}" || test -z "${REF_TYPE}"; then
  usage
  exit 1
fi

SCRIPT_DIR=$(dirname "${0}")
pushd "${SCRIPT_DIR}" &>/dev/null

PWD_DIR=$(pwd)

SANDBOX=$(mktemp -d)
echo "Making modifications in sandbox directory ${SANDBOX}"

cd "${SANDBOX}"
git clone git@gitlab.corp.pingidentity.com:ping-cloud-private-tenant/ping-cloud-base.git

echo ---
cd ping-cloud-base
git checkout "${SOURCE_REF}"

if test "${REF_TYPE}" = 'branch'; then
  # Create and checkout to target branch
  git checkout -b "${TARGET_REF}"

  # Update 'SERVER_PROFILE_BRANCH' variable
  echo "Changing ${SOURCE_REF} -> ${TARGET_REF} in SERVER_PROFILE_BRANCH variable"
  git grep -l "^SERVER_PROFILE_BRANCH=${SOURCE_REF}" | xargs sed -i.bak "s/^\(SERVER_PROFILE_BRANCH=\)${SOURCE_REF}$/\1${TARGET_REF}/g"

  # Update 'base/env_vars' image tags and yaml files
  replace_and_commit "${SOURCE_REF}-latest" "${TARGET_REF}-latest" "${REF_TYPE}"

elif test "${REF_TYPE}" = 'tag'; then
  # Update 'SERVER_PROFILE_BRANCH' variable
  echo "Changing ${SOURCE_REF} -> ${TARGET_REF} in SERVER_PROFILE_BRANCH variable"
  git grep -l "^SERVER_PROFILE_BRANCH=${SOURCE_REF}" | xargs sed -i.bak "s/^\(SERVER_PROFILE_BRANCH=\)${SOURCE_REF}$/\1${TARGET_REF}/g"

  # Update 'ECR_ENV' variable
  echo "Changing ECR_ENV variable "
  git grep -l "^ECR_ENV=/dev" | xargs sed -i.bak "s/\/dev//g"

  # Update 'base/env_vars' image tags and yaml files
  pip3 install -r "${PWD_DIR}"/python/requirements.txt > /dev/null
  replace_and_commit "${SOURCE_REF}-latest" "${TARGET_REF}" "${REF_TYPE}"

  # Verify no dev image paths in repo
  verify_k8s_image_repositories

  # Create tag
  git tag "${TARGET_REF}"

else
  usage
  exit 1
fi

echo ---
echo "Files that are different between origin/${SOURCE_REF} and ${TARGET_REF} refs:"
git diff --name-only origin/"${SOURCE_REF}" "${TARGET_REF}"

echo ---

# Confirm before pushing the tag to the server
read -n 1 -srp 'Press any key to continue'
git push origin "${TARGET_REF}"

popd &>/dev/null
