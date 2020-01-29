#!/bin/bash

########################################################################################################################
# Prints script usage
########################################################################################################################
usage() {
  echo "Usage: ${0} SOURCE_REF TARGET_REF"
  echo "  where"
  echo "    SOURCE_REF => source ref from where to create the target ref, e.g. master"
  echo "    TARGET_REF => the target ref, e.g. v1.0.0"
}

########################################################################################################################
# Replaces the current version references in the source ref with the target ref in all the necessary places. Must be
# in the ping-cloud-base directory for it to work correctly.
#
# Arguments:
#   ${1} -> The source ref
#   ${2} -> The target ref
########################################################################################################################
replace() {
  SOURCE_REF=${1}
  TARGET_REF=${2}

  # Replace K8S_GIT_BRANCH in generate-cluster-state.sh
  GENERATE_SCRIPT=code-gen/generate-cluster-state.sh
  GENERATE_SCRIPT_BAK=code-gen/generate-cluster-state.sh.bak
  cp "${GENERATE_SCRIPT}" "${GENERATE_SCRIPT_BAK}"

  export CI_COMMIT_REF_SLUG="${TARGET_REF}"
  envsubt "${CI_COMMIT_REF_SLUG}" < "${GENERATE_SCRIPT_BAK}" > "${GENERATE_SCRIPT}"
  rm -f "${GENERATE_SCRIPT_BAK}"

  # Replace SERVER_PROFILE_BRANCH variable in product-specific env_vars file
  PRODUCTS='pingdirectory pingfederate'
  for PRODUCT in pingdirectory ${PRODUCTS}; do
    sed -i.bak -E "s/(SERVER_PROFILE_BRANCH=).*$/\1${TARGET_REF}/" \
        "k8s-configs/ping-cloud/base/${PRODUCT}/base/env_vars"
  done

  # Verify references
  echo "Verifying presence of ${TARGET_REF} in expected files:"
  grep "${TARGET_REF}" "${GENERATE_SCRIPT}"

  for PRODUCT in pingdirectory ${PRODUCTS}; do
    grep "${TARGET_REF}" "k8s-configs/ping-cloud/base/${PRODUCT}/base/env_vars"
  done
}

SOURCE_REF=${1}
TARGET_REF=${2}

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
git checkout -- "${SOURCE_REF}"
replace "${SOURCE_REF}" "${TARGET_REF}"

git add .
git commit -m "[skip pipeline] - applying new tag ${TARGET_REF}"
git tag "${TARGET_REF}"

# Confirm before pushing the tag to the server
read -n 1 -srp 'Press any key to continue'
git push origin "${TARGET_REF}"

popd &> /dev/null