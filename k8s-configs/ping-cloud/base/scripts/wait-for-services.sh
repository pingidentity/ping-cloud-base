#!/bin/sh

. "./utils.lib.sh"

if test -z "${WAIT_FOR_SERVICES}"; then

  beluga_log "No dependent service found."
else
  
  beluga_log "Checking dependent service(s): ${WAIT_FOR_SERVICES}"

  for APP in ${WAIT_FOR_SERVICES}; do
    if test "${TENANT_DOMAIN}" != "${PRIMARY_TENANT_DOMAIN}"; then
      case "${APP}" in
          pingdirectory)
          HOST_PORT=${PD_CLUSTER_PUBLIC_HOSTNAME}:${PD_CLUSTER_PORT}
          ;;

          pingfederate-cluster)
          HOST_PORT=${PF_CLUSTER_PUBLIC_HOSTNAME}:${PF_CLUSTER_PORT}
          ;;

          pingaccess-admin)
          HOST_PORT=${PA_CLUSTER_PUBLIC_HOSTNAME}:${PA_CLUSTER_PORT}
          ;;

          pingaccess-was-admin)
          HOST_PORT=${PA_WAS_CLUSTER_PUBLIC_HOSTNAME}:${PA_WAS_CLUSTER_PORT}
          ;;
      esac
    else
      case "${APP}" in
          pingdirectory)
          HOST_PORT=${PD_CLUSTER_PRIVATE_HOSTNAME}:${PD_CLUSTER_PORT}
          ;;

          pingfederate-cluster)
          HOST_PORT=${PF_CLUSTER_PRIVATE_HOSTNAME}:${PF_CLUSTER_PORT}
          ;;

          pingaccess-admin)
          HOST_PORT=${PA_CLUSTER_PRIVATE_HOSTNAME}:${PA_CLUSTER_PORT}
          ;;

          pingaccess-was-admin)
          HOST_PORT=${PA_WAS_CLUSTER_PRIVATE_HOSTNAME}:${PA_WAS_CLUSTER_PORT}
          ;;
      esac
    fi 

    while true; do
      if test -z "${HOST_PORT}"; then 
        break
      fi

      if nc -z -v -w 2 "${HOST_PORT}"; then
        break
      fi 

      beluga_log "init: ${APP} Host '${HOST_PORT}' unreachable. Will try again in 2 seconds."
      sleep 2s
    done
  done 
fi

beluga_log "Execution completed successfully"

exit 0