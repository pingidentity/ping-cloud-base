#!/usr/bin/env sh

echo "pre-stop: starting pre-stop hook"

SHORT_HOST_NAME=$(hostname)
ORDINAL=${SHORT_HOST_NAME##*-}
echo "pre-stop: pod ordinal: ${ORDINAL}"

NUM_REPLICAS=$(kubectl get statefulset "${K8S_STATEFUL_SET_NAME}" -o jsonpath='{.spec.replicas}')
echo "pre-stop: number of replicas: ${NUM_REPLICAS}"

if test "${ORDINAL}" -lt "${NUM_REPLICAS}"; then
  echo "pre-stop: not removing server since it is still in the topology"
  exit 0
fi

# Conditionally remove the persistent volume to which the pod was bound.
if ! "${LEAVE_DISK_AFTER_SERVER_DELETE}"; then
  echo "pre-stop: remove the persistent volume"
  kubectl delete pvc out-dir-pingdirectory-"${ORDINAL}"
fi
