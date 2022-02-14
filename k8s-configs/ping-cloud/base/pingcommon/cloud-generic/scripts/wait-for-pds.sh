#!/bin/sh

. "./utils.lib.sh"

SLEEP_SECONDS=${INITIAL_DELAY_SECONDS:-0}

beluga_log "Initial delay: ${SLEEP_SECONDS}"
sleep "${SLEEP_SECONDS}"

SYNC_SERVERS="${DATASYNC_P1AS_SYNC_SERVER}.${PD_CLUSTER_PRIVATE_HOSTNAME}:${LDAPS_PORT} \
 ${DATASYNC_EXTERNAL_SYNC_SERVER_HOST}:${DATASYNC_EXTERNAL_SYNC_SERVER_PORT}"

# Append external PingDirectory HTTPS host if user want changelog enabled and max-age set for them.
if [ "${SET_EXTERNAL_SERVER_CHANGELOG_MAX_AGE_FOR_ME}" = "true" ]; then
  SYNC_SERVERS="${SYNC_SERVERS} ${DATASYNC_EXTERNAL_SYNC_SERVER_HOST}:${DATASYNC_EXTERNAL_SYNC_SERVER_HTTPS_PORT}"
fi

beluga_log "Checking sync servers: ${SYNC_SERVERS}"

for SERVER in ${SYNC_SERVERS}; do
  while true; do
    if nc -z -v -w 2 "${SERVER}"; then
      break
    fi

    beluga_log "'${SERVER}' unreachable. Will try again in 2 seconds."
    sleep 2s
  done # end of while-true loop
done #end of for-SERVER loop
beluga_log "Execution completed successfully"

exit 0