#!/usr/bin/env sh

echo "pre-stop: starting pre-stop hook"

SHORT_HOST_NAME=$(hostname)
ORDINAL=${SHORT_HOST_NAME##*-}
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

POST_START_INIT_MARKER_FILE="${SERVER_ROOT_DIR}"/config/post-start-init-complete
REPL_INIT_MARKER_FILE="${SERVER_ROOT_DIR}"/config/repl-initialized

echo "pre-stop: removing ${POST_START_INIT_MARKER_FILE} and ${REPL_INIT_MARKER_FILE} marker files"
rm -f "${POST_START_INIT_MARKER_FILE}" "${REPL_INIT_MARKER_FILE}"

# Conditionally remove the persistent volume to which the pod was bound.
if ! "${LEAVE_DISK_AFTER_SERVER_DELETE}"; then
  echo "pre-stop: remove the persistent volume"
  kubectl delete pvc out-dir-pingdirectory-"${ORDINAL}"
fi