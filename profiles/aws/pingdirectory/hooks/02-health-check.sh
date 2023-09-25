#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

# Perform finalization on exit
finalize() {
  beluga_log "PingDirectory available, re-enabling probes"

  # Remove 'exit 1' only if it exists on line 2
  sed -i '2{/^exit 1$/d;}' /opt/staging/hooks/85-readiness.sh

  # Remove 'exit 0' only if it exists on line 2
  sed -i '2{/^exit 0$/d;}' /opt/staging/hooks/86-liveness.sh
}

wait_until_server_is_available() {
  local pd_status=$(status | grep 'Operational Status' | cut -d ':' -f 2 | tr -d '[:space:]')

  if test "${pd_status}" == "Available"; then
    # Server is avaiable exit method
    return 0
  fi

  beluga_log "PingDirectory not available"
  sleep 60 # wait 60 seconds before trying again
  wait_until_server_is_available # recursive method will keep calling until server is available
}

# Trap all ERROR codes from here on so finalization is run
trap "finalize" ERR

beluga_log "Disabling probes at PingDirectory startup"
sed -i '2i exit 1' /opt/staging/hooks/85-readiness.sh
sed -i '2i exit 0' /opt/staging/hooks/86-liveness.sh

wait_until_server_is_available

# START workaround for STAGING-18792; PDO-6021;
# Easily access all global variables of base_dns for PingDirectory
all_base_dns="${PLATFORM_CONFIG_BASE_DN} \
  ${APP_INTEGRATIONS_BASE_DN} \
  ${USER_BASE_DN}"

# Iterate over all base DNs
# Continue to wait until all base DNs have been initialized
for base_dn in ${all_base_dns}; do
  while true; do
    # An un-initialized base DN is determined with the attribute ds-sync-generation-id set to -1
    init_status=$(ldapsearch \
      --outputFormat values-only \
      --baseDN "${base_dn}" \
      --scope base '(&)' ds-sync-generation-id)

    # if init_status is set to -1 then we must wait and try again until this base DN is initialized
    beluga_log "init_status for ${base_dn}: ${init_status}"
    if [[ "${init_status}" = "-1" ]]; then
      # Add a sleep to not overwhelm the system or the PingDirectory LDAP server and try again
      echo "PingDirectory not available, ${base_dn} is not yet initialized"
      sleep 15
    else
      beluga_log "PingDirectory base_dn:'${base_dn}' is initialized"
      # Break out of infinite while loop and move to the next base DN and check its ds-sync-generation-id value
      break
    fi
  done
done
# END workaround for STAGING-18792; PDO-6021;

# If there's lot of data from workaround for STAGING-18792; PDO-6021;
# Server can be back into degrade mode due to replication of data trying to catch up with latest.
# Check once more before re-enabling probes that server is 'Available'
wait_until_server_is_available

finalize