#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh" >/dev/null
. "${HOOKS_DIR}/utils.lib.sh" >/dev/null

echo get_all_running_pingdirectory_pods
name=$(get_all_running_pingdirectory_pods)
echo "$name"

echo get_other_running_pingdirectory_pods
name=$(get_other_running_pingdirectory_pods)
echo "$name"

if test is_first_pingdirectory_pod_in_cluster; then
  echo "is NOT genesis_server"
else
  echo "is_genesis_server"
fi

echo find_running_pingdirectory_pod_name_in_cluster
replicated=$(find_running_pingdirectory_pod_name_in_cluster)
echo $replicated

echo "PD_LIFE_CYCLE: $PD_LIFE_CYCLE"
if [ "${PD_LIFE_CYCLE}" = "START" ]; then
  if (is_primary_cluster && ! is_first_pingdirectory_pod_in_cluster) || is_secondary_cluster; then
    echo "I am a child non-seed server"
  else
    echo "I am parent seed server"
  fi
fi