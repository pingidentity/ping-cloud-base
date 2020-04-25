#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

if test ! "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"; then
  echo "pre-stop: skipping pre-stop on admin"
  exit
fi

echo "pre-stop: starting pre-stop hook on engine"

if test -z "${PA_ADMIN_PUBLIC_HOSTNAME}" || test -z "${PA_ENGINE_PUBLIC_HOSTNAME}"; then
  IS_MULTI_CLUSTER=false
else
  IS_MULTI_CLUSTER=true
fi

echo "pre-stop: multi-cluster: ${IS_MULTI_CLUSTER}"

if test "${IS_MULTI_CLUSTER}" = 'true'; then
  ADMIN_HOST_PORT="${PA_ADMIN_PUBLIC_HOSTNAME}"
  ENGINE_NAME="${PA_ENGINE_PUBLIC_HOSTNAME}:300${ORDINAL}"
else
  ADMIN_HOST_PORT="${K8S_SERVICE_NAME_PINGACCESS_ADMIN}:9000"
  ENGINE_NAME=$(hostname)
fi

# Retrieve Engine ID for engine name.
echo "pre-stop: removing engine ID for name ${ENGINE_NAME}"
OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines)
ENGINE_ID=$(jq -n "${OUT}" | jq --arg ENGINE_NAME "${ENGINE_NAME}" '.items[] | select(.name==$ENGINE_NAME) | .id')

if test -z "${ENGINE_ID}"; then
  echo "pre-stop: no engine ID found for name ${ENGINE_NAME}"
else
  echo "pre-stop: removing engine ID ${ENGINE_ID} for engine ${ENGINE_NAME}"
  make_api_request -X DELETE https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines/"${ENGINE_ID}"
  echo "pre-stop: status of removing engine ID ${ENGINE_ID} for engine ${ENGINE_NAME}: ${?}"
fi

echo "pre-stop: finished pre-stop hook"