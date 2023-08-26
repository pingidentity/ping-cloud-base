#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

echo get_running_pingdirectory_pods


if test is_genesis_server; then
  echo "is_genesis_server yay"
else
  echo "is NOT genesis_server"
fi

find_replicated_host_server