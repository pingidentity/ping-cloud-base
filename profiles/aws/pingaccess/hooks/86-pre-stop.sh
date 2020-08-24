#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

if test ! "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"; then
  echo "pre-stop: skipping pre-stop on admin"
  exit
fi

echo "pre-stop: starting pre-stop hook on engine"

SHORT_HOST_NAME=$(hostname)
ORDINAL=${SHORT_HOST_NAME##*-}

NUM_REPLICAS=$(kubectl get statefulset "${K8S_STATEFUL_SET_NAME}" -o jsonpath='{.spec.replicas}')
echo "pre-stop: number of replicas: ${NUM_REPLICAS}"

if test "${ORDINAL}" -lt "${NUM_REPLICAS}"; then
  echo "pre-stop: not removing engine since it is still in the topology"
  exit 0
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