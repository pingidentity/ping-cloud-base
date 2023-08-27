#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh" >/dev/null
. "${HOOKS_DIR}/utils.lib.sh" >/dev/null

name=$(get_other_running_pingdirectory_pods)
echo "$name"

if test is_first_time_deploy_child_server; then
  echo "is NOT genesis_server"
else
  echo "is_genesis_server yay"
fi

replicated=$(find_running_pingdirectory_pod_name_in_cluster)
echo $replicated

if [ "${RUN_PLAN}" = "START" ]; then
  if ( is_primary_cluster && ! is_first_running_pingdirectory_pod_in_cluster ) || is_secondary_cluster; then
    echo "yay it worked"
  fi
fi