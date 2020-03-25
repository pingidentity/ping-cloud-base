#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

set -x

if test ! -z "${OPERATIONAL_MODE}" && test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"; then
  
  # CERT_FLAG is used as a marker file that 1) tracks if server was initially configured and 2) Reload
  # admin configuration after creating engines keypair certificate. This should occur only once so the 
  # marker file will be created after these 2 things occur.
  #
  # If CERT_FLAG does not exist then set initial configuration and reload the configuration by using SIGHUP.
  CERT_FLAG=${OUT_DIR}/instance/certflag
  if ! test -f "${CERT_FLAG}"; then

    # Wait until pingaccess admin localhost is available
    pingaccess_admin_wait

    run_hook "81-import-initial-configuration.sh"

    SERVER=$(ps | pgrep sh | awk '{print $1; exit}')

    touch ${CERT_FLAG}

    echo "Reload PingAccess configuration"
    kill -SIGHUP "${SERVER}"

  fi

fi