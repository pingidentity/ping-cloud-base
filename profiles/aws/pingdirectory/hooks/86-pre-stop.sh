#!/usr/bin/env sh

echo "pre-stop: starting pre-stop hook"

SHORT_HOST_NAME=$(hostname)
ORDINAL=$(echo ${SHORT_HOST_NAME##*-})
echo "pre-stop: pod ordinal: ${ORDINAL}"

NUM_REPLICAS=$(kubectl get statefulset "${K8S_STATEFUL_SET_NAME}" -o jsonpath='{.spec.replicas}')
echo "pre-stop: number of replicas: ${NUM_REPLICAS}"

if test ${ORDINAL} -lt ${NUM_REPLICAS}; then
  echo "pre-stop: not removing server since it is still in the topology"
  exit 0
fi

echo "pre-stop: getting instance name from config"
INSTANCE_NAME=$(dsconfig --no-prompt \
  --useSSL --trustAll \
  --hostname "${HOSTNAME}" --port "${LDAPS_PORT}" \
  get-global-configuration-prop \
  --property instance-name \
  --script-friendly |
  awk '{ print $2 }')

echo "pre-stop: removing ${HOSTNAME} (instance name: ${INSTANCE_NAME}) from the topology"
dsreplication disable --disableAll \
  --no-prompt --ignoreWarnings \
  --retryTimeoutSeconds ${RETRY_TIMEOUT_SECONDS} \
  --enableDebug --globalDebugLevel verbose \
  --hostname "${HOSTNAME}" --port "${LDAPS_PORT}" \
  --adminUID "${ADMIN_USER_NAME}" --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}"
echo "pre-stop: server removal exited with return code: ${?}"

echo "pre-stop: removing the replication changelogDb"
rm -rf "${SERVER_ROOT_DIR}/changelogDb"

REPL_INIT_MARKER_FILE="${SERVER_ROOT_DIR}"/config/repl-initialized

echo "pre-stop: removing ${REPL_INIT_MARKER_FILE} marker files"
rm -f "${REPL_INIT_MARKER_FILE}"

# Tell Kubernetes to delete the persistent volume we were bound to. This makes the above cleanup unnecessary, but
# we will keep that around in case this fails for some reason.
echo "pre-stop: remove the persistent volume"
kubectl delete pvc out-dir-pingdirectory-"${ORDINAL}"