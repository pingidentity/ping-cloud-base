#!/usr/bin/env sh
#
# Script Return Code:
#
#  0: Success
#  1: Non-fatal error, all requests processed before aborting (show all errors) 
#  2: Fatal error, something totally unexpected occured, exit immediately.
#
${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"


function startServer()
{
   #
   # Run Pingfederate on localhost interface to complete configuration prior to exposing the
   # admin server to the external environment. This also takes care of cases where a restart
   # is necessary following a change.
   #
   cd /opt/out/instance/bin
   cp run.properties run.properties.bak
   sed -i -e 's/pf.console.bind.address=0.0.0.0/pf.console.bind.address=127.0.0.1/' run.properties
   ./run.sh &
   wait_for_admin_api_endpoint 
   #
   # Restore run properties now we've started the server.
   #
   cp run.properties.bak run.properties
}


function applyGeneralOverrides()
{
   rc=0
   if [ -e "${STAGING_DIR}/data-overrides" ] && [ -d "${STAGING_DIR}/data-overrides" ]; then
      beluga_log "============================= Applying general static overrides =============================="
      cd ${STAGING_DIR}/data-overrides
      beluga_log "Directory: $(pwd)"
      rm ./README.txt
      beluga_log "Processing Template Files"
      for template in $( find "." -type f -iname \*.subst ) ; do
         beluga_log "    t - ${template}"
         envsubst < "${template}" > "${template%.subst}"
         rm -f "${template}"
      done
      beluga_log "Copying override files"
      ( find . -type f -exec cp -avfL --parents '{}' "${SERVER_ROOT_DIR}/server/default/data" \; )

      rc=$? 
      beluga_log "================================  General overrides applied  ================================="
   else
      beluga_log "============================ No general overrides found to apply ============================="
   fi
   return ${rc}
}


function applyConfigStoreOverrides()
{
   rc=0
   cd "${STAGING_DIR}/config-store"
   if [ $(ls *.json  2>/dev/null| wc -l) -gt 0 ]; then
      #
      # Overrides exist, process directroy contents in lexicographical order              
      #
      beluga_log "==========================  Applying config store static overrides ==========================="
      #
      # Assume Success, we will attempt to process everything to catch all errors in one pass
      #
      for file in $(ls *.json |sort |tr '$\n' ' '); do
         #
         # Only process files
         #
         if [ -f "${file}" ]; then
            #
            # Load file for processing
            #
            bundle=$(cat ./${file})
            #
            # Extract data from file
            #
            target=$(echo "${bundle}" | jq -r '.bundle')
            method=$(echo "${bundle}" | jq -r '.method'| tr '[:lower:]' '[:upper:]')
            payload=$(echo "${bundle}" | jq -r '.payload')
            id=$(echo "${payload}" | jq -r '.id')
            #
            # Validate Method, only PUT, DEL(ETE) allowed
            #
            if [ "${method}" = "PUT" ] || [ "${method}" = "DEL" ] || [ "${method}" = "DELETE" ]; then
               #
               # Construct API Call to get current value
               #
               set +x
               oldValue=$(curl -s -k \
                  -H 'X-Xsrf-Header: PingFederate' \
                  -H 'Accept: application/json' \
                  -u "Administrator:${PF_ADMIN_USER_PASSWORD}" \
                  -w '%{http_code}' \
                  -X GET \
                  "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/configStore/${target}/${id}")
               ${VERBOSE} && set -x
               result=$(echo "${oldValue:$(echo "${#oldValue} -3" |bc)}" | tr -d '$\n')
               oldValue=$(echo "${oldValue:0:-3}" | tr -d '$\n' )
               #
               # An http response of 404 means the item wasn't found, this may or may not
               # be an error in the request, there is no way to tell. If this is a delete
               # operation then we may have already delted it on a prior start. If this is
               # a put operation then the value could be new, for example overriding an 
               # undefined default value. 
               #
               if [ "${result}" != "200" ] && [ "${result}" != "404" ]; then
                  #
                  # Something Unexpected Happened 
                  #
                  oldValue="Unexpected Error occurred, HTTP Status: ${result}"
                  newValue=""
                  rc=2
               else   
                  if [ "${result}" = "404" ]; then
                     oldValue="Item not found in configuration store"
                  fi
                  #
                  #  Construct API call to Change/delete value
                  #
                  case ${method} in
                     DEL | DELETE)
                        #
                        # Process delete request
                        #
                         if [ "${result}" = "404" ]; then
                           #
                           # Non-existent entity, ignore request.
                           #
                           newValue=""
                        else
                           set +x 
                           result=$(curl -s -k \
                                    -H 'X-Xsrf-Header: PingFederate' \
                                    -H 'Accept: application/json' \
                                    -u "Administrator:${PF_ADMIN_USER_PASSWORD}" \
                                    -w '%{http_code}' \
                                    -o /dev/null \
                                    -X DELETE \
                                     "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/configStore/${target}/${id}")
                           ${VERBOSE} && set -x
                           case ${result} in
                              404)
                                 newValue="Entity disappeared between read and delete!"
                                 rc=1
                                 ;;
                              403)
                                 newValue="Bundle not available - unable to process request!"
                                 rc=1
                              ;;
                              204)
                                 newValue="Entity deleted!"
                                 ;;
                              *)
                                 newValue="Unexpected Error occurred HTTP status: ${result}"
                                 rc=2
                                  ;;
                           esac
                        fi
                        ;;
                
                     PUT)
                        #
                        # Process put request
                        #
                        set +x
                        newValue=$(curl -s -k \
                                    -H 'X-Xsrf-Header: PingFederate' \
                                    -H 'Accept: application/json' \
                                    -H "Content-Type: application/json" \
                                    -u "Administrator:${PF_ADMIN_USER_PASSWORD}" \
                                    -w '%{http_code}' \
                                    -d "${payload}" \
                                    -X PUT \
                                     "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/configStore/${target}/${id}")
                        ${VERBOSE} && set -x
                        result="${newValue##*\}}"
                        newValue=$(echo "${newValue:0:-3}" | tr -d '$\n')
                        case ${result} in
                           422)
                              newValue="Validation Error occurred: ${newValue}"
                              rc=1
                               ;;
                           403)
                               newValue="Bundle not available - unable to process request!"
                              rc=1
                              ;;
                           200)
                              ;;
                           *)
                              newValue="Unexpected Error occurred HTTP status: ${result}"
                              rc=2
                               ;;
                        esac
                         ;;
                     *)
                        rc=2
                        ;; 
                  esac
               
                  beluga_log "${separator}"
                  beluga_log "Processing Override: ${file}"
                  beluga_log "Bundle:              ${target}"
                  beluga_log "Id:                  ${id}"
                  beluga_log "Operation:           ${method}"
                  beluga_log "Payload:             $(echo "${payload}" | tr '$\n' ' ')"
                  beluga_log ""
                  beluga_log "HTTP Response code:  ${result}"
                  beluga_log "Old Value:           ${oldValue}"
                  beluga_log "New Value:           ${newValue}"
                  separator="----------------------------------------------------------------------------------------------"
               fi
            fi
         fi
         if [ "${rc}" = "2" ]; then
            break
         fi
      done
      beluga_log "===========================  Config store static overrides applied ==========================="
   else
       beluga_log "No config store static overrides found to applied"
   fi
   return ${rc}
}


function stopServer()
{
   #
   # Shut down temporary PingFederate instance
   #
   cd /opt/out/instance/bin
   pid=$(cat pingfederate.pid)
   kill ${pid}
   beluga_log "Waiting for PingFederate to shutdown" 
   while [  "$(netstat -lntp|grep ${PF_ADMIN_PORT}|grep "${pid}/java" >/dev/null 2>&1;echo $?)" = "0" ]; do
      sleep 1
   done
   sleep 1
   kill -9 ${pid} 2> /dev/null   
}
#---------------------------------------------------------------------------------------------
# Main Script
#---------------------------------------------------------------------------------------------
#
# Note current location.
#
wd=$(pwd)
#
# Decide if there is any work to do
#
hasGeneralOverride=0
hasConfigStoreOverride=0

 if [ -e "${STAGING_DIR}/data-overrides" ] && 
    [ -d "${STAGING_DIR}/data-overrides" ] && 
    [ "$(ls ${STAGING_DIR}/data-overrides|grep -v "README.txt"|wc -l|tr -d ' ')" != "0" ]; then
    hasGeneralOverride=1
 fi

 if [ -e "${STAGING_DIR}/config-store" ] && 
    [ -d "${STAGING_DIR}/config-store" ] && 
    [ "$(ls ${STAGING_DIR}/config-store|grep -v "README.txt"|wc -l|tr -d ' ')" != "0" ]; then
    hasConfigStoreOverride=1
 fi

if [ ${hasGeneralOverride} -eq 1 ] || [ ${hasConfigStoreOverride} -eq 1 ]; then
   startServer
   applyGeneralOverrides
   rc1=$?
   applyConfigStoreOverrides
   rc2=$?
   stopServer
   rc=$(echo "( ${rc1} * 10) + ${rc2}"|bc)
else
   beluga_log "No data or config store overrides found to applied - Do nothing"   
fi

cd ${wd}
exit ${rc}
