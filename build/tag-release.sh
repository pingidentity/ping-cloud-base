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

  # Replace SERVER_PROFILE_BRANCH variable in product-specific env_vars file
  PRODUCTS='pingdirectory pingfederate'
  for PRODUCT in ${PRODUCTS}; do
    sed -i.bak -E "s/(SERVER_PROFILE_BRANCH=).*$/\1${TARGET_REF}/" \
        "k8s-configs/ping-cloud/base/${PRODUCT}/base/env_vars"
  done

  # Verify references
  echo ---
  for PRODUCT in ${PRODUCTS}; do
    FILE="k8s-configs/ping-cloud/base/${PRODUCT}/base/env_vars"
    echo "Verifying file ${FILE}"
    grep "${TARGET_REF}" "${FILE}"
  done
  echo ---

  echo "Creating new ${REF_TYPE} ${TARGET_REF}"
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
cd ping-cloud-base

if test "${REF_TYPE}" = 'tag'; then
  replaceAndCommit "${SOURCE_REF}" "${TARGET_REF}" "${REF_TYPE}"
  git tag "${TARGET_REF}"
else
  git checkout -b "${TARGET_REF}" "origin/${SOURCE_REF}"
  replaceAndCommit "${SOURCE_REF}" "${TARGET_REF}" "${REF_TYPE}"
fi

# Confirm before pushing the tag to the server
read -n 1 -srp 'Press any key to continue'
git push origin "${TARGET_REF}"

popd &> /dev/null