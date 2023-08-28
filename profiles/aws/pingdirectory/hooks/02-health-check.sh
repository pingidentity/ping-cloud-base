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

# Trap all ERROR codes from here on so finalization is run
trap "finalize" ERR

beluga_log "Disabling probes at PingDirectory startup"
sed -i '2i exit 1' /opt/staging/hooks/85-readiness.sh
sed -i '2i exit 0' /opt/staging/hooks/86-liveness.sh

while true; do
  sleep 60
  PD_STATUS=$(status | grep 'Operational Status' | cut -d ':' -f 2 | tr -d '[:space:]')

  if test "${PD_STATUS}" == "Available"; then
    # START workaround for STAGING-18792; PDO-6021;
    # Easily access all global variables of base_dns for PingDirectory
    all_base_dns="${PLATFORM_CONFIG_BASE_DN} \
      ${APP_INTEGRATIONS_BASE_DN} \
      ${USER_BASE_DN}"

    # Iterate over all base DNs
    # Continue to wait until all base DNs have been initialized
    for base_dn in ${all_base_dns}; do
      while true; do
        # An un-initialized baseDN is determined with the attribute ds-sync-generation-id set to -1
        init_status=$(ldapsearch \
          --outputFormat values-only \
          --baseDN "${base_dn}" \
          --scope base '(&)' ds-sync-generation-id)

        # if init_status is set to -1 then we must try again until this baseDN is initialized
        beluga_log "int_status for ${base_dn}: ${init_status}"
        if [[ "${init_status}" = "-1" ]]; then
          # Add a sleep to not overwhelm the system or the LDAP server
          echo "Directory not available, ${base_dn} is not yet initialized"
          sleep 5
        else
          beluga_log "Directory base_dn:'${base_dn}' is initialized"
          break
        fi
      done
    done
    # END workaround for STAGING-18792; PDO-6021;

    # Explicitly call finalize to restore readiness and liveness before exiting the script
    finalize
    break
  fi
  beluga_log "PingDirectory not available"
done
