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
# commits the changes into the target ref (branch or tag). Must be in the ping-cloud-base directory for it to work
# correctly.
#
# Arguments:
#   ${1} -> The source ref
#   ${2} -> The target ref
#   ${3} -> The ref type, tag or branch
########################################################################################################################
replaceAndCommit() {
  SOURCE_REF=${1}
  TARGET_REF=${2}
  REF_TYPE=${3}

  echo "Changing ${SOURCE_REF} -> ${TARGET_REF} in expected files"
  git grep -l "${SOURCE_REF}" | xargs sed -i.bak "s/${SOURCE_REF}/${TARGET_REF}/g"

  echo "Committing changes for new ${REF_TYPE} ${TARGET_REF}"
  git add .
  git commit -m "[skip pipeline] - creating new ${REF_TYPE} ${TARGET_REF}"
}

SOURCE_REF=${1}
TARGET_REF=${2}
REF_TYPE=${3:-tag}

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
  replaceAndCommit "${SOURCE_REF}" "${TARGET_REF}" "${REF_TYPE}"
  git tag "${TARGET_REF}"
else
  git checkout -b "${TARGET_REF}"
  replaceAndCommit "${SOURCE_REF}" "${TARGET_REF}" "${REF_TYPE}"
fi

echo ---
echo "Files that are different between origin/${SOURCE_REF} and ${TARGET_REF} refs:"
git diff --name-only origin/"${SOURCE_REF}" "${TARGET_REF}"
echo ---

# Confirm before pushing the tag to the server
read -n 1 -srp 'Press any key to continue'
git push origin "${TARGET_REF}"

popd &> /dev/null
