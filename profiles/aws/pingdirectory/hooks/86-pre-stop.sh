#!/usr/bin/env sh

. "${HOOKS_DIR}/utils.lib.sh"

beluga_log "pre-stop: starting pre-stop hook"

SHORT_HOST_NAME=$(hostname)
ORDINAL=${SHORT_HOST_NAME##*-}
beluga_log "pre-stop: pod ordinal: ${ORDINAL}"

NUM_REPLICAS=$(kubectl get statefulset "${K8S_STATEFUL_SET_NAME}" -o jsonpath='{.spec.replicas}')
beluga_log "pre-stop: number of replicas: ${NUM_REPLICAS}"

if test ${ORDINAL} -lt ${NUM_REPLICAS}; then
  beluga_log "pre-stop: not removing server since it is still in the topology"
  exit 0
fi

# Conditionally remove the persistent volume to which the pod was bound.
if ! "${LEAVE_DISK_AFTER_SERVER_DELETE}"; then
  beluga_log "pre-stop: remove the persistent volume"
  kubectl delete pvc out-dir-pingdirectory-"${ORDINAL}"
fi