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
    if is_secondary_cluster; then
      case "${APP}" in
        pingdirectory)
          # In secondary clusters, only non-pingdirectory servers and pingdirectory-0 (the seed server for its cluster)
          # need to wait on the pingdirectory service in primary. Secondary non-0 pingdirectory won't be started until
          # pingdirectory-0 is Ready within its own cluster during initial launch because they run in a StatefulSet
          # with 'OrderedReady' pod management policy. On rolling update (which rolls pods in reverse order), it is
          # still necessary for at least one of the servers to be able to reach the pingdirectory service in primary,
          # and pingdirectory-0 works for this also.
          ! is_a_pingdirectory_server || is_pingdirectory_server0 &&
              HOST_PORT_LIST="\
                ${PD_CLUSTER_PUBLIC_HOSTNAME}:${PD_CLUSTER_PORT}"
          ;;

        pingfederate-cluster)
          HOST_PORT_LIST="\
            ${PF_CLUSTER_PUBLIC_HOSTNAME}:${PF_CLUSTER_PORT} \
            ${PF_ADMIN_SERVER_NAME}.${PF_CLUSTER_PUBLIC_HOSTNAME}:${PF_ADMIN_WAIT_PORT}"
          ;;

        pingaccess-admin)
          HOST_PORT_LIST="\
            ${PA_CLUSTER_PUBLIC_HOSTNAME}:${PA_CLUSTER_PORT} \
            ${PA_ADMIN_SERVER_NAME}.${PA_CLUSTER_PUBLIC_HOSTNAME}:${PA_ADMIN_WAIT_PORT}"
          ;;

        pingaccess-was-admin)
          HOST_PORT_LIST="${PA_WAS_CLUSTER_PUBLIC_HOSTNAME}:${PA_WAS_CLUSTER_PORT} \
            ${PA_WAS_ADMIN_SERVER_NAME}.${PA_WAS_CLUSTER_PUBLIC_HOSTNAME}:${PA_WAS_ADMIN_WAIT_PORT}"
          ;;
      esac
    else
      case "${APP}" in
        pingdirectory)
          # In the primary cluster, pingdirectory servers don't need to wait on the pingdirectory service. Being in a
          # StatefulSet with 'OrderReady' pod management policy makes it unnecessary.
          ! is_a_pingdirectory_server &&
              HOST_PORT_LIST="\
                ${PD_CLUSTER_PRIVATE_HOSTNAME}:${PD_CLUSTER_PORT}"
          ;;

        pingfederate-cluster)
          HOST_PORT_LIST="\
            ${PF_CLUSTER_PRIVATE_HOSTNAME}:${PF_CLUSTER_PORT} \
            ${PF_ADMIN_SERVER_NAME}.${PF_ADMIN_SERVICE_NAME}:${PF_ADMIN_WAIT_PORT}"
          ;;

        pingaccess-admin)
          HOST_PORT_LIST="${PA_CLUSTER_PRIVATE_HOSTNAME}:${PA_CLUSTER_PORT} \
            ${PA_ADMIN_SERVER_NAME}.${PA_ADMIN_SERVICE_NAME}:${PA_ADMIN_WAIT_PORT}"
          ;;

        pingaccess-was-admin)
          HOST_PORT_LIST="${PA_WAS_CLUSTER_PRIVATE_HOSTNAME}:${PA_WAS_CLUSTER_PORT} \
            ${PA_WAS_ADMIN_SERVER_NAME}.${PA_WAS_ADMIN_SERVICE_NAME}:${PA_WAS_ADMIN_WAIT_PORT}"
          ;;
      esac
    fi

    if test -z "${HOST_PORT_LIST}"; then
      beluga_log "No services to wait for"
      continue
    fi

    for HOST_PORT in ${HOST_PORT_LIST}; do
      beluga_log "Waiting for service: ${HOST_PORT}"

      while true; do
        if nc -z -v -w 2 "${HOST_PORT}"; then
          break
        fi

        beluga_log "${APP} at '${HOST_PORT}' unreachable. Will try again in 2 seconds."
        sleep 2s
      done # end of while-true loop
    done # end of HOST_PORT loop

  done # end of for-APP loop
fi

beluga_log "Execution completed successfully"

exit 0