#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

########################################################################################################################
# Format version for numeric comparison.
#
# Arguments
#   ${1} -> The version string, e.g. 10.0.0.
########################################################################################################################
format_version() {
  printf "%03d%03d%03d%03d" $(echo "${1}" | tr '.' ' ')
}

########################################################################################################################
# Get the version of the pingfederate server in the provided directory.
#
# Arguments
#   ${1} -> The target directory containing server bits.
########################################################################################################################
get_version() {
  TARGET_DIR="${1}"

  SCRATCH_DIR=$(mktemp -d)
  find "${TARGET_DIR}" -name pf-startup.jar | xargs -I {} cp {} "${SCRATCH_DIR}"

  cd "${SCRATCH_DIR}"
  unzip pf-startup.jar &> /dev/null
  VERSION=$(grep version META-INF/maven/pingfederate/pf-startup/pom.properties | cut -d= -f2)
  cd - &> /dev/null
}

########################################################################################################################
# Get the version of the pingfederate server packaged in the image.
########################################################################################################################
get_image_version() {
  get_version "${SERVER_BITS_DIR}"
  IMAGE_VERSION="${VERSION}"
}

########################################################################################################################
# Get the currently installed version of the pingfederate server.
########################################################################################################################
get_installed_version() {
  get_version "${SERVER_ROOT_DIR}"
  INSTALLED_VERSION="${VERSION}"
}

#---------------------------------------------------------------------------------------------
# Main Script
#---------------------------------------------------------------------------------------------

# Check if it's necessary to run the upgrade tool
# Compare version in /opt/server with current version of server under /opt/out/instance to make the call
get_image_version
beluga_log "Image version is: ${IMAGE_VERSION}"

get_installed_version
beluga_log "Installed version is: ${INSTALLED_VERSION}"

if test $(format_version "${IMAGE_VERSION}") -gt $(format_version "${INSTALLED_VERSION}"); then
  # PingFederate requires that the source and target installation have the directory name "pingfederate"
  # More info here: https://docs.pingidentity.com/bundle/pingfederate-93/page/tit1564003034981.html
  beluga_log "Changing the name of the source and target directories to 'pingfederate'"

  OLD_SERVER_ROOT_DIR="${OUT_DIR}/pingfederate"
  rm -rf "${OLD_SERVER_ROOT_DIR}"
  beluga_log "Copying ${SERVER_ROOT_DIR} to ${OLD_SERVER_ROOT_DIR}"
  cp -pr "${SERVER_ROOT_DIR}" "${OLD_SERVER_ROOT_DIR}"

  NEW_SERVER_ROOT_DIR="/opt/pingfederate"
  rm -rf "${NEW_SERVER_ROOT_DIR}"
  beluga_log "Copying ${SERVER_BITS_DIR} to ${NEW_SERVER_ROOT_DIR}"
  cp -pr "${SERVER_BITS_DIR}" "${NEW_SERVER_ROOT_DIR}"

  beluga_log "Upgrading from ${INSTALLED_VERSION} -> ${IMAGE_VERSION}"
  beluga_log "Running upgrade.sh from ${NEW_SERVER_ROOT_DIR} against source server at ${OLD_SERVER_ROOT_DIR}"
  sh "${NEW_SERVER_ROOT_DIR}/upgrade/bin/upgrade.sh" "${OLD_SERVER_ROOT_DIR}" --release-notes-reviewed

  UPGRADE_STATUS=${?}
  beluga_log "Upgrade from ${INSTALLED_VERSION} -> ${IMAGE_VERSION}: ${UPGRADE_STATUS}"
  test "${UPGRADE_STATUS}" -ne 0 && exit "${UPGRADE_STATUS}"

  beluga_log "Moving new server root at ${NEW_SERVER_ROOT_DIR} to original server root at ${SERVER_ROOT_DIR}"
  rm -rf "${SERVER_ROOT_DIR}"
  rm -rf "${OLD_SERVER_ROOT_DIR}"
  mv "${NEW_SERVER_ROOT_DIR}" "${SERVER_ROOT_DIR}"
else
  beluga_log "Not running upgrade because image version is not newer than installed version"
fi