#!/usr/bin/env sh
${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"
. "${HOOKS_DIR}/util/config-query-keypair-utils.sh"

if test ! "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"; then
  beluga_log "upgrade: skipping upgrade on engine"
  exit
fi

templates_dir_path="${STAGING_DIR}"/templates/81

#---------------------------------------------------------------------------------------------
# Process Possible Admin Upgrade
#---------------------------------------------------------------------------------------------
function process_admin()
{
   pingaccess_admin_api_endpoint="https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3"
   #
   # Check if it's necessary to run the upgrade tool. Compare version in /opt/server with current 
   # version of server under /opt/out/instance to make the call.
   #
   IMAGE_VERSION=
   get_image_version
   beluga_log "Image version is: ${IMAGE_VERSION}"

   INSTALLED_VERSION=
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
      run_hook "15-update-jvm-settings.sh"
      "${SERVER_ROOT_DIR}"/bin/run.sh &
      pingaccess_admin_wait

      # Upgrade the keypair on the Config Query HTTPS Listener
      upgrade_config_query_listener_keypair "${templates_dir_path}"
      test $? -ne 0 && return 1

      #
      # old instance now running, if this is the admin server disable key rotation 
      #
      beluga_log "Disabling key rotation to prevent invalidating active sessions during upgrade"

      original=$(make_api_request "${pingaccess_admin_api_endpoint}/authTokenManagement")
      test $? -ne 0 && return 1

      original=$(echo "${original}" | tr -s ' '| tr '\n' ' ')
      payload="$(echo "${original}" | jq -r ".keyRollEnabled |= false" | tr -s ' '|tr -d '\n' )"
      make_api_request -X PUT -d "${payload}" \
         "${pingaccess_admin_api_endpoint}/authTokenManagement" > /dev/null
      test $? -ne 0 && return 1

      #
      # copy New server into place
      #
      cp -pr  "${SERVER_BITS_DIR}"/* "${NEW_INSTANCE_DIR}"

      #
      # Copy /jvm-memory.options file to new install
      #
      cp "${SERVER_ROOT_DIR}"/conf/jvm-memory.options "${NEW_INSTANCE_DIR}"/conf

      #
      # PDO-2027 - Boost the logging for log4j2.xml on the target
      #
      cp "${NEW_INSTANCE_DIR}"/conf/log4j2.xml "${NEW_INSTANCE_DIR}"/conf/log4j2.xml.orig
      sed -i '/<Loggers>/a <AsyncLogger name="com.pingidentity.pa.spring.config.plugin.ConfigurablePluginPostProcessor" level="TRACE"/>' "${NEW_INSTANCE_DIR}"/conf/log4j2.xml

      #
      # PDO-1426 removed restore backup configuration from S3 upon container restart.
      # Therefore, we need to copy /h2_password_properties.backup file to new install
      #
      if [ -f "${SERVER_ROOT_DIR}"/conf/h2_password_properties.backup ]; then
         cp "${SERVER_ROOT_DIR}"/conf/h2_password_properties.backup "${NEW_INSTANCE_DIR}"/conf
      fi

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

      # Upgrade complete
      beluga_log "Upgrade complete, now terminating old server instance"
      stop_server

      # PDO-2027 - Export upgrade target instance logs to CloudWatch
      beluga_log_file_contents "${NEW_INSTANCE_DIR}"/log/pingaccess.log 'PA UPGRADE TARGET INSTANCE LOG'

      # PDO-2027 - After the upgrade, restore the original log4j2.xml file to eliminate TRACE
      # logging noise.
      beluga_log "Removing ConfigurablePluginPostProcessor TRACE logging"
      mv "${NEW_INSTANCE_DIR}"/conf/log4j2.xml.orig "${NEW_INSTANCE_DIR}"/conf/log4j2.xml

      #
      # Export upgrade logs to CloudWatch
      #
      for file in $(ls   "${NEW_INSTANCE_DIR}"/upgrade/log); do
         beluga_log_file_contents "${NEW_INSTANCE_DIR}"/upgrade/log/${file} 'UPGRADE LOG'
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
      if [ ${rc} -eq 0 ]; then
         #
         # Delete and recreate server instance directory
         #
         rm -rf "${SERVER_ROOT_DIR}"
         mkdir -p "${SERVER_ROOT_DIR}"
         mv  "${NEW_INSTANCE_DIR}"/* "${SERVER_ROOT_DIR}"

         # Restore marker files
         touch "${ADMIN_CONFIGURATION_COMPLETE}"
      else
         #
         # Re-enable key rotation following failed upgrade attempt
         #
         beluga_log "Upgrade failed: Re-enabling key rotation"

         make_api_request -X PUT -d "${original}" \
            "${pingaccess_admin_api_endpoint}/authTokenManagement" > /dev/null
         test $? -ne 0 && return 1
      fi

      #
      # Clear admin user for upgrade
      #
      unset PA_SOURCE_API_USERNAME

      #
      # Clear password for source server
      #
      unset PA_SOURCE_API_PASSWORD

   else
      beluga_log "Not running upgrade because image version is not newer than installed version"
   fi
   return ${rc}
}

#---------------------------------------------------------------------------------------------
# Main Script
#---------------------------------------------------------------------------------------------
process_admin
exit ${?}