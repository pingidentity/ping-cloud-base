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
# Get the version of the pingaccess server in the provided directory.
#
# Arguments
#   ${1} -> The target directory containing server bits.
########################################################################################################################
get_version() {
  TARGET_DIR="${1}"

  SCRATCH_DIR=$(mktemp -d)
  find "${TARGET_DIR}" -name pingaccess-admin-ui*.jar | xargs -I {} cp {} "${SCRATCH_DIR}"

  cd "${SCRATCH_DIR}"
  unzip pingaccess-admin-ui*.jar &> /dev/null
  VERSION=$(grep version META-INF/maven/com.pingidentity.pingaccess/pingaccess-admin-ui/pom.properties | cut -d= -f2)
  cd - &> /dev/null
}

########################################################################################################################
# Get the version of the pingaccess server packaged in the image.
########################################################################################################################
get_image_version() {
  get_version "${SERVER_BITS_DIR}"
  IMAGE_VERSION="${VERSION}"
}

########################################################################################################################
# Get the currently installed version of the pingaccess server.
########################################################################################################################
get_installed_version() {
  get_version "${SERVER_ROOT_DIR}"
  INSTALLED_VERSION="${VERSION}"
}


#---------------------------------------------------------------------------------------------
# Execut PUT command against api
#---------------------------------------------------------------------------------------------

function api_put()
{
   cmd='curl -s -k -H "X-Xsrf-Header:·PingAccess" -H "Accept: application/json" -H "Content-Type: application/json" -X PUT -d'
   cmd=" ${cmd} ' ${2} ' -w %{http_code} -o ${OUT_DIR}/api_response.txt"
   cmd=" ${cmd} -u ${PA_ADMIN_USER_USERNAME}:${PA_ADMIN_USER_PASSWORD} --retry ${API_RETRY_LIMIT} --max-time ${API_TIMEOUT_WAIT}"
   cmd=" ${cmd} --retry-delay 1 --retry-connrefused ${1}"
   http_code=$(eval ${cmd})
   curl_result=$?

   if test "${curl_result}" -ne 0; then
        beluga_log "Admin API connection refused"
       "${STOP_SERVER_ON_FAILURE}" && stop_server || exit 1
   fi

   if test "${http_code}" -ne 200; then
        beluga_log "API call returned HTTP status code: ${http_code}"
       "${STOP_SERVER_ON_FAILURE}" && stop_server || exit 1
   fi

   cat ${OUT_DIR}/api_response.txt && rm -f ${OUT_DIR}/api_response.txt

   return 0
}

#---------------------------------------------------------------------------------------------
# Main Script
#---------------------------------------------------------------------------------------------

#
# Check if it's necessary to run the upgrade tool. Compare version in /opt/server with current 
#version of server under /opt/out/instance to make the call.
#
get_image_version
beluga_log "Image version is: ${IMAGE_VERSION}"
get_installed_version
beluga_log "Installed version is: ${INSTALLED_VERSION}"

if test $(format_version "${IMAGE_VERSION}") -gt $(format_version "${INSTALLED_VERSION}"); then
   beluga_log "Ping Access Version change detected - attempting upgrade, this may fail under certain conditions"

   #
   # Figure out what we're upgrading
   #
   UPGRADE_TARGET="$(grep "pa.operational.mode" ${SERVER_ROOT_DIR}/conf/run.properties|cut -d= -f2)"

   #
   # create temp directory for new instanc builde
   #
   NEW_INSTANCE_DIR="/tmp/$(basename ${SERVER_ROOT_DIR})"
   rm -vrf "${NEW_INSTANCE_DIR}"
   mkdir -vp "${NEW_INSTANCE_DIR}"

   #
   # start old instance, and wait for it to be ready
   #
   "${SERVER_ROOT_DIR}"/bin/run.sh &
   pingaccess_admin_wait

   #
   # old instance now running, if this is the admin server disable key rotation 
   #
   if [ "${UPGRADE_TARGET}" = "CLUSTERED_CONSOLE" ]; then
      beluga_log "Disabling key rotation to prevent invalidating active sessions during upgrade"
      original=$(make_api_request "https://localhost:${PINGACCESS_ADMIN_SERVICE_PORT}/pa-admin-api/v3/authTokenManagement" | tr -s ' '| tr '\n' ' ')
      payload="$(echo "${original}" | jq -r ".keyRollEnabled |= false" | tr -s ' '|tr -d '\n' )"
      payload=$(api_put "https://localhost:${PINGACCESS_ADMIN_SERVICE_PORT}/pa-admin-api/v3/authTokenManagement" "${payload}")
      payload=$(make_api_request "https://localhost:${PINGACCESS_ADMIN_SERVICE_PORT}/pa-admin-api/v3/authTokenManagement")
   fi
   #
   # copy New server into place
   #
   cp -pr  "${SERVER_BITS_DIR}"/* "${NEW_INSTANCE_DIR}"

   #
   # Copy /jvm-memory.options file to new install
   #
   cp "${SERVER_ROOT_DIR}"/conf/jvm-memory.options "${NEW_INSTANCE_DIR}"/conf

   #
   # Navigate to upgrade utility directory in new server
   #

   cd "${NEW_INSTANCE_DIR}"/upgrade/bin

   #
   # Set admin user for upgrade
   #
   export PA_SOURCE_API_USERNAME="${PA_ADMIN_USER_USERNAME}"

   #
   # Set password for source server
   #
   export PA_SOURCE_API_PASSWORD="${PA_ADMIN_USER_PASSWORD}"

   #
   # Figure out which license file to use 
   #
   if [ -z "${NEW_LICENSE_FILE}" ]; then
      NEW_LICENSE_FILE="${SERVER_ROOT_DIR}/conf/pingaccess.lic"
   fi

   #
   # If an upgrade port was supplied use it otherwise use the default
   #
   UPGRADE_PORT="${PA_UPGRADE_ADMIN_PORT:-9001}"

   #
   # Are we upgrading the cluster console? if so we want to disable replication
   #
   if [ "${UPGRADE_TARGET}" = "CLUSTERED_CONSOLE" ]; then
      REPLICATION_OPTION="-r"
   else
      REPLICATION_OPTION=""
   fi

   #
   # Perform server upgrade
   #
   sh ./upgrade.sh -s ${REPLICATION_OPTION} -p ${UPGRADE_PORT} -i "${NEW_INSTANCE_DIR}" -l "${NEW_LICENSE_FILE}" "${SERVER_ROOT_DIR}"
   #
   # Check if upgrade succeeded, and report status 
   #
   rc=${?}
   beluga_log "Upgrade from ${INSTALLED_VERSION} -> ${IMAGE_VERSION}  Return Code: ${rc}"

   #
   # Export upgrade logs to CloudWatch
   #
   for file in $(ls   "${NEW_INSTANCE_DIR}"/upgrade/log); do
      beluga_log "-----------------------------------------------------------------"
      beluga_log " UPGRADE LOG: /opt/out/instance/upgrade/log/${file}"
      beluga_log "-----------------------------------------------------------------"
      while IFS= read -r line; do
          beluga_log "${line}"
       done < "${NEW_INSTANCE_DIR}"/upgrade/log/${file}
   done

   #-------------------------------------------------------------------------------------
   # This script is designed to idempotent if the server upgrade fails, this is to allow
   # a restart with the original image without the need to perform a restore, although 
   # the script exits with the upgrade return code and will therfore crash loop on 
   # failure.
   #
   # If upgrade was successful move new server into place. 
   #
   #-------------------------------------------------------------------------------------

   if [ "${rc}" = "0" ]; then
      #
      # Delete and recreate server instance directory
      #
      rm -rf "${SERVER_ROOT_DIR}"
      mkdir -vp "${SERVER_ROOT_DIR}"
      mv  "${NEW_INSTANCE_DIR}"/* "${SERVER_ROOT_DIR}"

   else
      #
      # Renable key rotation following failed upgrade attempt
      #
      beluga_log "Upgrade failed: Re-enabling key rotation"
      payload=$(api_put "https://localhost:${PINGACCESS_ADMIN_SERVICE_PORT}/pa-admin-api/v3/authTokenManagement" "${original}")
   fi

   #
   # Clear admin user for upgrade
   #
   export PA_SOURCE_API_USERNAME=""

   #
   # Clear password for source server
   #
   export PA_SOURCE_API_PASSWORD=""

else
   beluga_log "Not running upgrade because image version is not newer than installed version"
fi
exit ${rc}
