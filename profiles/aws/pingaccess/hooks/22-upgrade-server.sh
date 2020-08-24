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
# Get the version of the Pingaccess server in the provided directory.
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
# Get the version of the Pingaccess server packaged in the image.
########################################################################################################################
get_image_version() {
  get_version "${SERVER_BITS_DIR}"
  IMAGE_VERSION="${VERSION}"
}

########################################################################################################################
# Get the currently installed version of the Pingaccess server.
########################################################################################################################
get_installed_version() {
  get_version "${SERVER_ROOT_DIR}"
  INSTALLED_VERSION="${VERSION}"
}


#---------------------------------------------------------------------------------------------
# Execute PUT command against api
#---------------------------------------------------------------------------------------------

function api_put()
{
   set +x
   cmd='curl -s -k -H "X-Xsrf-Header:·PingAccess" -H "Accept: application/json" -H "Content-Type: application/json" -X PUT -d'
   cmd=" ${cmd} ' ${2} ' -w %{http_code} -o ${OUT_DIR}/api_response.txt"
   cmd=" ${cmd} -u ${PA_ADMIN_USER_USERNAME}:${PA_ADMIN_USER_PASSWORD} --retry ${API_RETRY_LIMIT} --max-time ${API_TIMEOUT_WAIT}"
   cmd=" ${cmd} --retry-delay 1 --retry-connrefused ${1}"
   http_code=$(eval ${cmd})
   curl_result=$?
   ${VERBOSE} && set -x

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
# Process Possible Admin Upgrade
#---------------------------------------------------------------------------------------------
function process_admin()
{
   #
   # Check if it's necessary to run the upgrade tool. Compare version in /opt/server with current 
   # version of server under /opt/out/instance to make the call.
   #
   get_image_version
   beluga_log "Image version is: ${IMAGE_VERSION}"
   get_installed_version
   beluga_log "Installed version is: ${INSTALLED_VERSION}"

   if test $(format_version "${IMAGE_VERSION}") -gt $(format_version "${INSTALLED_VERSION}"); then
      beluga_log "Ping Access Version change detected - attempting upgrade, this may fail under certain conditions"

      #
      # create temp directory for new instance build
      #
      NEW_INSTANCE_DIR="/tmp/$(basename ${SERVER_ROOT_DIR})"
      rm -rf "${NEW_INSTANCE_DIR}"
      mkdir -p "${NEW_INSTANCE_DIR}"

      #
      # start old instance, and wait for it to be ready
      #
      "${SERVER_ROOT_DIR}"/bin/run.sh &
      pingaccess_admin_wait

      #
      # old instance now running, if this is the admin server disable key rotation 
      #
      beluga_log "Disabling key rotation to prevent invalidating active sessions during upgrade"
      original=$(make_api_request "https://localhost:${PINGACCESS_ADMIN_SERVICE_PORT}/pa-admin-api/v3/authTokenManagement" | tr -s ' '| tr '\n' ' ')
      payload="$(echo "${original}" | jq -r ".keyRollEnabled |= false" | tr -s ' '|tr -d '\n' )"
      payload=$(api_put "https://localhost:${PINGACCESS_ADMIN_SERVICE_PORT}/pa-admin-api/v3/authTokenManagement" "${payload}")
      payload=$(make_api_request "https://localhost:${PINGACCESS_ADMIN_SERVICE_PORT}/pa-admin-api/v3/authTokenManagement")
   
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
      # Perform server upgrade
      #
      sh ./upgrade.sh -s -r -p ${UPGRADE_PORT} -i "${NEW_INSTANCE_DIR}" -l "${NEW_LICENSE_FILE}" "${SERVER_ROOT_DIR}"
   
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
      # This script is designed to be idempotent if the server upgrade fails, this is to 
      # allow a restart with the original image without the need to perform a restore, 
      # although the script exits with the upgrade return code and will therefore crash loop 
      # on failure in order to alert operations. This approach also prevents the server
      # reaching the backup step, potentially corrupting the backup by executing the wrong
      # PA version.
      #-------------------------------------------------------------------------------------
      
      #
      # If upgrade was successful move new server into place. 
      #
      if [ "${rc}" = "0" ]; then
         #
         # Delete and recreate server instance directory
         #
         rm -rf "${SERVER_ROOT_DIR}"
         mkdir -p "${SERVER_ROOT_DIR}"
         mv  "${NEW_INSTANCE_DIR}"/* "${SERVER_ROOT_DIR}"
      else
         #
         # Re-enable key rotation following failed upgrade attempt
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
   return ${rc}
}

#---------------------------------------------------------------------------------------------
# Handle Engine replication 
#---------------------------------------------------------------------------------------------
function process_engine()
{
   rc=0

   #
   # Establish which PA version this image is running
   #     
   get_image_version
   beluga_log "Engine Image version is: ${IMAGE_VERSION}"

   #
   # Establish running version of the admin server
   #
   INSTALLED_ADMIN=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/version| jq -r .version)

   #
   # Are the admin and Engine running the same version? 
   #
   if test $(format_version "${IMAGE_VERSION}") -eq $(format_version "${INSTALLED_ADMIN}"); then
      #
      # Yes, get engine details
      #
      engines=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines)
      engineId=$(jq -n "${engines}" | jq -r --arg ENGINE_NAME "$(hostname)" '.items[] | select(.name==$ENGINE_NAME) | .id')
      if [ -n "${engineId}" ] && [ "${engineId}" != "null" ]; then
         #
         # Pre-existing engine, check replication state.
         #
         engine=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines/${engineId})
         state=$(jq -n "${engine}" | jq -r ".configReplicationEnabled")
         #
         # If replication is disabled then re-enable it
         #
         if [ "${state}" = "false" ]; then
            engine=$(echo "${engine}" | jq -r ".configReplicationEnabled |= true" | tr -s ' '|tr -d '\n' )
            engine=$(api_put "https://${ADMIN_HOST_PORT}/pa-admin-api/v3/engines/${engineId}" "${engine}")
            beluga_log "Configuration replication re-enabled for $(hostname)"
         fi   
      fi   
   else
      #
      # System is in an illegal state
      #
      beluga_log "FATAL ERROR ILLEGAL STATE VERSION MISMATCH: Engine version ${IMAGE_VERSION} Admin Version ${INSTALLED_ADMIN}"
      rc=1
   fi  
   return ${rc}
}
#---------------------------------------------------------------------------------------------
# Main Script
#---------------------------------------------------------------------------------------------

#
# Figure out what kind of server we are.
#
UPGRADE_TARGET="$(grep "pa.operational.mode" ${SERVER_ROOT_DIR}/conf/run.properties|cut -d= -f2)"

#
# Decide course of action depending on type of server
#
if [ "${UPGRADE_TARGET}" = "CLUSTERED_CONSOLE" ]; then
   process_admin
   exit ${?}
elif [ "${UPGRADE_TARGET}" = "CLUSTERED_ENGINE" ]; then 
   process_engine
   exit ${?}
else
   beluga_log "Upgrading ${UPGRADE_TARGET} is not supported - exiting"
   exit 1   
fi

