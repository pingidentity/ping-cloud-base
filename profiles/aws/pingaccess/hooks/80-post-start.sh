#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

set -x

if test ! -z "${OPERATIONAL_MODE}" && test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"; then
  
  # ADMIN_CONFIGURATION_COMPLETE is used as a marker file that tracks if server was initially configured.
  #
  # If ADMIN_CONFIGURATION_COMPLETE does not exist then set initial configuration.
  ADMIN_CONFIGURATION_COMPLETE=${OUT_DIR}/instance/ADMIN_CONFIGURATION_COMPLETE
  if ! test -f "${ADMIN_CONFIGURATION_COMPLETE}"; then

    # Wait until pingaccess admin localhost is available
    pingaccess_admin_wait

    run_hook "81-import-initial-configuration.sh"
    if test ${?} -ne 0; then
      SERVER_PID=$(pgrep -alf java | grep 'run.properties' | awk '{ print $1; }')
      kill "${SERVER_PID}"
    fi

    touch ${ADMIN_CONFIGURATION_COMPLETE}
  fi

fi

exit 0