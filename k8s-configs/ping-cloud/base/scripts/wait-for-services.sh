#!/bin/sh

. "./utils.lib.sh"

SLEEP_SECONDS=${INITIAL_DELAY_SECONDS:-0}

beluga_log "Initial delay: ${SLEEP_SECONDS}"
sleep "${SLEEP_SECONDS}"

if test -z "${WAIT_FOR_SERVICES}"; then

  beluga_log "No dependent service found."
else

  beluga_log "Checking dependent service(s): ${WAIT_FOR_SERVICES}"

  for APP in ${WAIT_FOR_SERVICES}; do
    if test "${TENANT_DOMAIN}" != "${PRIMARY_TENANT_DOMAIN}"; then
      case "${APP}" in
          pingdirectory)
          HOSTNAME=${PD_CLUSTER_PUBLIC_HOSTNAME}
          PORTS=${PD_CLUSTER_PORTS}
          ;;

          pingfederate-cluster)
          HOSTNAME=${PF_CLUSTER_PUBLIC_HOSTNAME}
          PORTS=${PF_CLUSTER_PORTS}
          ;;

          pingaccess-admin)
          HOSTNAME=${PA_CLUSTER_PUBLIC_HOSTNAME}
          PORTS=${PA_CLUSTER_PORTS}
          ;;

          pingaccess-was-admin)
          HOSTNAME=${PA_WAS_CLUSTER_PUBLIC_HOSTNAME}
          PORTS=${PA_WAS_CLUSTER_PORTS}
          ;;
      esac
    else
      case "${APP}" in
          pingdirectory)
          HOSTNAME=${PD_CLUSTER_PRIVATE_HOSTNAME}
          PORTS=${PD_CLUSTER_PORTS}
          ;;

          pingfederate-cluster)
          HOSTNAME=${PF_CLUSTER_PRIVATE_HOSTNAME}
          PORTS=${PF_CLUSTER_PORTS}
          ;;

          pingaccess-admin)
          HOSTNAME=${PA_CLUSTER_PRIVATE_HOSTNAME}
          PORTS=${PA_CLUSTER_PORTS}
          ;;

          pingaccess-was-admin)
          HOSTNAME=${PA_WAS_CLUSTER_PRIVATE_HOSTNAME}
          PORTS=${PA_WAS_CLUSTER_PORTS}
          ;;
      esac
    fi

    while true; do
      if test -z "${HOSTNAME}" || test -z "${PORTS}"; then
        break
      fi

      for PORT in ${PORTS}
      do
        if nc -z -v -w 2 "${PORT}"; then
          PORTS=$(echo "${PORTS}" | sed "s/${PORT}//g")
        else
          beluga_log "init: ${APP} Host:'${HOSTNAME}' Port:'${PORT}' unreachable. Will try again in 2 seconds."
          sleep 2s
        fi
      done

      if test -z "${PORTS}"; then
        break
      fi
    done
  done
fi

beluga_log "Execution completed successfully"

exit 0