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
# Replaces the current version references in the source ref with the target ref in all the necessary places. Then,
# commits the changes into the target ref(branch or tag). Must be in the ping-cloud-base directory for it to work
# correctly.
#
# Arguments:
#   ${1} -> The source ref
#   ${2} -> The target ref
#   ${3} -> The ref type- tag or branch
########################################################################################################################
replaceAndCommit() {
  SOURCE=${1}
  TARGET=${2}
  REF_TYPE=${3}

  echo "Changing ${SOURCE} -> ${TARGET} in expected files"

  #update base env vars

  grep_var "PINGACCESS_IMAGE_TAG" "${SOURCE}" "${TARGET}"
  grep_var "PINGACCESS_WAS_IMAGE_TAG" "${SOURCE}" "${TARGET}"
  grep_var "PINGFEDERATE_IMAGE_TAG" "${SOURCE}" "${TARGET}"
  grep_var "PINGDIRECTORY_IMAGE_TAG" "${SOURCE}" "${TARGET}"
  grep_var "PINGDELEGATOR_IMAGE_TAG" "${SOURCE}" "${TARGET}"
  grep_var "PINGCENTRAL_IMAGE_TAG" "${SOURCE}" "${TARGET}"
  grep_var "PINGDATASYNC_IMAGE_TAG" "${SOURCE}" "${TARGET}"
  grep_var "METADATA_IMAGE_TAG" "${SOURCE}" "${TARGET}"
  grep_var "HEALTHCHECK_IMAGE_TAG" "${SOURCE}" "${TARGET}"
  grep_var "P14C_BOOTSTRAP_IMAGE_TAG" "${SOURCE}" "${TARGET}"
  grep_var "P14C_INTEGRATION_IMAGE_TAG" "${SOURCE}" "${TARGET}"
  grep_var "ANSIBLE_BELUGA_IMAGE_TAG" "${SOURCE}" "${TARGET}"

  #update k8s yaml files

  grep_yaml "pingaccess" "pingcloud-apps" "${SOURCE}" "${TARGET}" "${REF_TYPE}"
  grep_yaml "pingaccess-was" "pingcloud-apps" "${SOURCE}" "${TARGET}" "${REF_TYPE}"
  grep_yaml "pingfederate" "pingcloud-apps" "${SOURCE}" "${TARGET}" "${REF_TYPE}"
  grep_yaml "pingdirectory" "pingcloud-apps" "${SOURCE}" "${TARGET}" "${REF_TYPE}"
  grep_yaml "pingdelegator" "pingcloud-apps" "${SOURCE}" "${TARGET}" "${REF_TYPE}"
  grep_yaml "pingcentral" "pingcloud-apps" "${SOURCE}" "${TARGET}" "${REF_TYPE}"
  grep_yaml "pingdatasync" "pingcloud-apps" "${SOURCE}" "${TARGET}" "${REF_TYPE}"
  grep_yaml "p14c-bootstrap" "pingcloud-services" "${SOURCE}" "${TARGET}" "${REF_TYPE}"
  grep_yaml "p14c-integration" "pingcloud-services" "${SOURCE}" "${TARGET}" "${REF_TYPE}"
  grep_yaml "metadata" "pingcloud-services" "${SOURCE}" "${TARGET}" "${REF_TYPE}"
  grep_yaml "healthcheck" "pingcloud-services" "${SOURCE}" "${TARGET}" "${REF_TYPE}"
  grep_yaml "ansible-beluga" "pingcloud-solutions" "${SOURCE}" "${TARGET}" "${REF_TYPE}"

  echo "Committing changes for new ${REF_TYPE} ${TARGET}"
  git add .
  git commit -m "[skip pipeline] - creating new ${REF_TYPE} ${TARGET}"
}

grep_var() {

  local var=${1}
  local source_value=${2}
  local target_value=${3}

  echo "Changing ${source_value} -> ${target_value} in expected files"

  git grep -l "^${var}=${source_value}" | xargs sed -i.bak "s/^\(${var}=\)${source_value}$/\1${target_value}/g"

}

grep_yaml() {

  local var=${1}
  local ecr_repo=${2}
  local source_value=${3}
  local target_value=${4}
  local ref_value=${5}

  local dev_ecr_path="image: public.ecr.aws/r2h3l6e4/${ecr_repo}/${var}/dev"
  local prod_ecr_path="image: public.ecr.aws/r2h3l6e4/${ecr_repo}/${var}"

  local source_image="${dev_ecr_path}:${source_value}"

  cd "${SANDBOX}"/ping-cloud-base/k8s-configs
  git grep -l "${source_image}" | xargs sed -i.bak "s/${source_value}/${target_value}/g"

  if test "${ref_value}" = 'branch'; then
    local target_image="${dev_ecr_path}:${target_value}"

  elif test "${ref_value}" = 'tag'; then
    local target_image="${prod_ecr_path}:${target_value}"

    # update the ecr path to prod from dev
    git grep -l "${dev_ecr_path}" | xargs sed -i.bak "s/\/dev//g"

  else
    usage
    exit 1
  fi

  echo "Updated from  ${source_image} -> ${target_image} in expected files"

  cd "${SANDBOX}"/ping-cloud-base/

}

SOURCE_REF=${1}
TARGET_REF=${2}
REF_TYPE=${3}

if test -z "${SOURCE_REF}" || test -z "${TARGET_REF}"; then
  usage
  exit 1
fi

SCRIPT_DIR=$(dirname "${0}")
pushd "${SCRIPT_DIR}" &>/dev/null

SANDBOX=$(mktemp -d)
echo "Making modifications in sandbox directory ${SANDBOX}"

cd "${SANDBOX}"
git clone git@gitlab.corp.pingidentity.com:ping-cloud-private-tenant/ping-cloud-base.git

echo ---
cd ping-cloud-base
git checkout "${SOURCE_REF}"

###########################################################################################################################
# Verifies the 'REF_TYPE' if its a 'tag' or 'branch'.
#
# (1) -->if the 'REF_TYPE' is a 'branch' then --> creates new branch and adds new changes on the new branch as follows -
#
# updates 'SERVER_PROFILE_BRANCH' variable with target  branch name (v*.*-release-branch)
# updates 'base/env_vars' image tags with target branch name (v*.*-release-branch-latest)
# updates yaml files docker images with target branch name (v*.*-release-branch-latest)
#
# eg: `build/tag-release.sh v1.14-release-branch v1.15-release-branch branch`
#
# (2) -->if the 'REF_TYPE' is a 'tag' then --> adds new changes as follows and then creates a new tag -
#
# updates 'SERVER_PROFILE_BRANCH' variable with target tag name (v*.*.*.*_RC1)
# updates 'base/env_vars' image tags with target tag name (v*.*.*.*_RC1)
# updates yaml files docker images target tag name (v*.*.*.*_RC1) 
# updates the ecr path to 'prod' from 'dev'
#
# eg: `build/tag-release.sh v1.14-release-branch v1.14.0.0_RC1`
#
###########################################################################################################################

if test "${REF_TYPE}" = 'branch'; then

  # Create and checkout to target branch
  git checkout -b "${TARGET_REF}"

  # Update 'SERVER_PROFILE_BRANCH' variable
  echo "Changing ${SOURCE_REF} -> ${TARGET_REF} in SERVER_PROFILE_BRANCH variable"
  git grep -l "^SERVER_PROFILE_BRANCH=${SOURCE_REF}" | xargs sed -i.bak "s/^\(SERVER_PROFILE_BRANCH=\)${SOURCE_REF}$/\1${TARGET_REF}/g"

  # Update 'base/env_vars' image tags and yaml files
  echo "Changing ${SOURCE_REF}-latest -> ${TARGET_REF}-latest in base/env_vars and yaml files"
  replaceAndCommit "${SOURCE_REF}-latest" "${TARGET_REF}-latest" "${REF_TYPE}"

elif test "${REF_TYPE}" = 'tag'; then

  # Update 'SERVER_PROFILE_BRANCH' variable
  echo "Changing ${SOURCE_REF} -> ${TARGET_REF} in SERVER_PROFILE_BRANCH variable"
  git grep -l "^SERVER_PROFILE_BRANCH=${SOURCE_REF}" | xargs sed -i.bak "s/^\(SERVER_PROFILE_BRANCH=\)${SOURCE_REF}$/\1${TARGET_REF}/g"

  # Update 'ECR_ENV' variable
  echo "Changing ECR_ENV variable "
  git grep -l "^ECR_ENV=/dev" | xargs sed -i.bak "s/\/dev//g"

  # Update 'base/env_vars' image tags and yaml files
  echo "Changing ${SOURCE_REF}-latest -> ${TARGET_REF} in base/env_vars and yaml files"
  replaceAndCommit "${SOURCE_REF}-latest" "${TARGET_REF}" "${REF_TYPE}"
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
