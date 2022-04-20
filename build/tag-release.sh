#!/bin/bash -e

########################################################################################################################
# Prints script usage
########################################################################################################################
usage() {
  echo "Usage: ${0} SOURCE_REF TARGET_REF [REF_TYPE]"
  echo "  where"
  echo "    SOURCE_REF => source ref from where to create the target ref, e.g. master"
  echo "    TARGET_REF => the target ref, e.g. v1.0.0"
  echo "    REF_TYPE => the target ref type - tag or branch, default is tag"
}

########################################################################################################################
# Replaces the current version references in the source ref with the target ref in all the necessary places. Then,
# commits the changes into the target ref(tag). Must be in the ping-cloud-base directory for it to work
# correctly.
#
# Arguments:
#   ${1} -> The source ref
#   ${2} -> The target ref
#   ${3} -> The ref type, tag or branch
########################################################################################################################
replaceAndCommit_tag() {
  SOURCE_REF=${1}
  TARGET_REF=${2}
  REF_TYPE=${3}

  echo "Changing ${SOURCE_REF} -> ${TARGET_REF} in expected files"
  # git grep -l "^SERVER_PROFILE_BRANCH=${SOURCE_REF}" | xargs sed -i.bak "s/^\(SERVER_PROFILE_BRANCH=\)${SOURCE_REF}$/\1${TARGET_REF}/g"

  #update base env vars
  # git grep -l "^PINGACCESS_IMAGE_TAG=${SOURCE_REF}" | xargs sed -i.bak "s/^\(PINGACCESS_IMAGE_TAG=\)${SOURCE_REF}$/\1${TARGET_REF}/g"
  # git grep -l "^PINGACCESS_WAS_IMAGE_TAG=${SOURCE_REF}" | xargs sed -i.bak "s/^\(PINGACCESS_WAS_IMAGE_TAG=\)${SOURCE_REF}$/\1${TARGET_REF}/g" 
  # git grep -l "^PINGFEDERATE_IMAGE_TAG=${SOURCE_REF}" | xargs sed -i.bak "s/^\(PINGFEDERATE_IMAGE_TAG=\)${SOURCE_REF}$/\1${TARGET_REF}/g"
  # git grep -l "^PINGDIRECTORY_IMAGE_TAG=${SOURCE_REF}" | xargs sed -i.bak "s/^\(PINGDIRECTORY_IMAGE_TAG=\)${SOURCE_REF}$/\1${TARGET_REF}/g"
  # git grep -l "^PINGDELEGATOR_IMAGE_TAG=${SOURCE_REF}" | xargs sed -i.bak "s/^\(PINGDELEGATOR_IMAGE_TAG=\)${SOURCE_REF}$/\1${TARGET_REF}/g"
  # git grep -l "^PINGCENTRAL_IMAGE_TAG=${SOURCE_REF}" | xargs sed -i.bak "s/^\(PINGCENTRAL_IMAGE_TAG=\)${SOURCE_REF}$/\1${TARGET_REF}/g"
  # git grep -l "^PINGDATASYNC_IMAGE_TAG=${SOURCE_REF}" | xargs sed -i.bak "s/^\(PINGDATASYNC_IMAGE_TAG=\)${SOURCE_REF}$/\1${TARGET_REF}/g"

  #update base env vars

  grep_var "PINGACCESS_IMAGE_TAG" "${SOURCE_REF}" "${TARGET_REF}"
  grep_var "PINGACCESS_WAS_IMAGE_TAG" "${SOURCE_REF}" "${TARGET_REF}"
  grep_var "PINGFEDERATE_IMAGE_TAG" "${SOURCE_REF}" "${TARGET_REF}"
  grep_var "PINGDIRECTORY_IMAGE_TAG" "${SOURCE_REF}" "${TARGET_REF}-"
  grep_var "PINGDELEGATOR_IMAGE_TAG" "${SOURCE_REF}" "${TARGET_REF}"
  grep_var "PINGCENTRAL_IMAGE_TAG" "${SOURCE_REF}" "${TARGET_REF}"
  grep_var "PINGDATASYNC_IMAGE_TAG" "${SOURCE_REF}" "${TARGET_REF}"

  echo "Committing changes for new ${REF_TYPE} ${TARGET_REF}"
  git add .
  git commit -m "[skip pipeline] - creating new ${REF_TYPE} ${TARGET_REF}"
}

########################################################################################################################
# Replaces the current version references in the source ref with the target ref in all the necessary places. Then,
# commits the changes into the target ref (branch ). Must be in the ping-cloud-base directory for it to work
# correctly.
#
# Arguments:
#   ${1} -> The source ref
#   ${2} -> The target ref
#   ${3} -> The ref type, tag or branch
########################################################################################################################
replaceAndCommit_branch() {
  SOURCE_REF=${1}
  TARGET_REF=${2}


  #update base env vars

  grep_var "PINGACCESS_IMAGE_TAG" "${SOURCE_REF}-latest" "${TARGET_REF}-latest"
  grep_var "PINGACCESS_WAS_IMAGE_TAG" "${SOURCE_REF}-latest" "${TARGET_REF}-latest"
  grep_var "PINGFEDERATE_IMAGE_TAG" "${SOURCE_REF}-latest" "${TARGET_REF}-latest"
  grep_var "PINGDIRECTORY_IMAGE_TAG" "${SOURCE_REF}-latest" "${TARGET_REF}-latest"
  grep_var "PINGDELEGATOR_IMAGE_TAG" "${SOURCE_REF}-latest" "${TARGET_REF}-latest"
  grep_var "PINGCENTRAL_IMAGE_TAG" "${SOURCE_REF}-latest" "${TARGET_REF}-latest"
  grep_var "PINGDATASYNC_IMAGE_TAG" "${SOURCE_REF}-latest" "${TARGET_REF}-latest"


  echo "Committing changes for new ${REF_TYPE} ${TARGET_REF}"
  git add .
  git commit -m "[skip pipeline] - creating new ${REF_TYPE} ${TARGET_REF}"
}

grep_var() {

  VAR=${1}
  SOURCE_VALUE=${2}
  TARGET_VALUE=${3}

  echo "Changing ${SOURCE_VALUE} -> ${TARGET_VALUE} in expected files"

  git grep -l "^${VAR}=${SOURCE_VALUE}" | xargs sed -i.bak "s/^\(${VAR}=\)${SOURCE_VALUE}$/\1${TARGET_VALUE}/g"

}

SOURCE_REF=${1}
TARGET_REF=${2}
REF_TYPE=${3}

if test -z "${SOURCE_REF}" || test -z "${TARGET_REF}"; then
  usage
  exit 1
fi

SCRIPT_DIR=$(dirname "${0}")
pushd "${SCRIPT_DIR}" &> /dev/null

SANDBOX=$(mktemp -d)
echo "Making modifications in sandbox directory ${SANDBOX}"

cd "${SANDBOX}"
git clone git@gitlab.corp.pingidentity.com:ping-cloud-private-tenant/ping-cloud-base.git

echo ---
cd ping-cloud-base
git checkout "${SOURCE_REF}"

if test "${REF_TYPE}" = 'tag'; then
  replaceAndCommit_tag "${SOURCE_REF}" "${TARGET_REF}" "${REF_TYPE}"
  git tag "${TARGET_REF}"
else
  git checkout -b "${TARGET_REF}"
  replaceAndCommit_branch "${SOURCE_REF}" "${TARGET_REF}" 
fi

echo ---
echo "Files that are different between origin/${SOURCE_REF} and ${TARGET_REF} refs:"
# git diff --name-only origin/"${SOURCE_REF}" "${TARGET_REF}"
git diff origin/"${SOURCE_REF}" "${TARGET_REF}"
echo ---

# Confirm before pushing the tag to the server
read -n 1 -srp 'Press any key to continue'
# git push origin "${TARGET_REF}"

popd &> /dev/null
