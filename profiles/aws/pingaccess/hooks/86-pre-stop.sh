#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

export_environment_variables

if test ! "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"; then
  beluga_log "pre-stop: skipping pre-stop on admin"
  exit
fi

beluga_log "pre-stop: starting pre-stop hook on engine"

SHORT_HOST_NAME=$(hostname)
ORDINAL=${SHORT_HOST_NAME##*-}

NUM_REPLICAS=$(kubectl get statefulset "${K8S_STATEFUL_SET_NAME_PINGACCESS}" -o jsonpath='{.spec.replicas}')
beluga_log "pre-stop: number of replicas: ${NUM_REPLICAS}"

if test "${ORDINAL}" -lt "${NUM_REPLICAS}"; then
  beluga_log "pre-stop: not removing engine ${ORDINAL} since it is still in the topology"
  exit 0
fi

ADMIN_HOST_PORT="${K8S_SERVICE_NAME_PINGACCESS_ADMIN}:9000"
ENGINE_NAME="${SHORT_HOST_NAME}"

# Retrieve Engine ID for engine name.
beluga_log "pre-stop: removing engine ID for name ${ENGINE_NAME}"
OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines)
ENGINE_ID=$(jq -n "${OUT}" | jq --arg ENGINE_NAME "${ENGINE_NAME}" '.items[] | select(.name==$ENGINE_NAME) | .id')

if test -z "${ENGINE_ID}"; then
  beluga_log "pre-stop: no engine ID found for name ${ENGINE_NAME}"
else
  beluga_log "pre-stop: removing engine ID ${ENGINE_ID} for engine ${ENGINE_NAME}"
  make_api_request -X DELETE https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines/"${ENGINE_ID}"
  beluga_log "pre-stop: status of removing engine ID ${ENGINE_ID} for engine ${ENGINE_NAME}: ${?}"
fi

beluga_log "pre-stop: finished pre-stop hook"