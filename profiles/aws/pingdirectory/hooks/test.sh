#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh" >/dev/null
. "${HOOKS_DIR}/utils.lib.sh" >/dev/null

name=$(get_other_running_pingdirectory_pods)
echo "$name"

if test is_genesis_server; then
  echo "is_genesis_server yay"
else
  echo "is NOT genesis_server"
fi

replicated=$(find_replicated_host_server)
echo $replicated