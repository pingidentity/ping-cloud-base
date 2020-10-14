#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

test -f "${HOOKS_DIR}/pingdirectory.lib.sh" && . "${HOOKS_DIR}/pingdirectory.lib.sh"

if test "${ORDINAL}" -ne 0 || ! is_primary_cluster; then
  beluga_error 'replication cannot be initialized - this script must be run on the first server in the primary cluster'
  exit 1
fi

BASE_DNS=${BASE_DNS:-${DNS_TO_ENABLE}}

beluga_log "replication will be initialized for base DNs: ${BASE_DNS}"
initStatus=0

for DN in ${BASE_DNS}; do
  initialize_all_servers_for_dn "${DN}"
  replInitResult=$?

  if test ${replInitResult} -eq 0; then
    # Add the base DN to the replication-init marker file, if not already present
    if ! grep -qi "${DN}" "${REPL_INIT_MARKER_FILE}" 2>/dev/null; then
      echo "${DN}" >> "${REPL_INIT_MARKER_FILE}"
    fi
  else
    # Remove the base DN from the replication-init marker file, if present
    sed -i "s/${DN}/d" "${REPL_INIT_MARKER_FILE}"

    beluga_error "replication data could be initialized for base DN ${DN} on one or more servers"
    initStatus=${replInitResult}
  fi
done

exit ${initStatus}