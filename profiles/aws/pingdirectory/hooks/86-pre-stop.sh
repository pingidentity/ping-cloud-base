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

echo "pre-stop: gettting instance name from config"
INSTANCE_NAME=$(dsconfig --no-prompt \
  --useSSL --trustAll \
  --hostname "${HOSTNAME}" --port "${LDAPS_PORT}" \
  get-global-configuration-prop \
  --property instance-name \
  --script-friendly |
  awk '{ print $2 }')

echo "pre-stop: removing ${HOSTNAME} (instance name: ${INSTANCE_NAME}) from the topology"
remove-defunct-server --no-prompt \
  --serverInstanceName "${INSTANCE_NAME}" \
  --retryTimeoutSeconds ${RETRY_TIMEOUT_SECONDS} \
  --ignoreOnline \
  --bindDN "${ROOT_USER_DN}" \
  --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
  --enableDebug --globalDebugLevel verbose
echo "pre-stop: server removal exited with return code: ${?}"

POST_START_INIT_MARKER_FILE="${SERVER_ROOT_DIR}"/config/post-start-init-complete
REPL_INIT_MARKER_FILE="${SERVER_ROOT_DIR}"/config/repl-initialized

echo "pre-stop: removing ${POST_START_INIT_MARKER_FILE} and ${REPL_INIT_MARKER_FILE} marker files"
rm -f "${POST_START_INIT_MARKER_FILE}" "${REPL_INIT_MARKER_FILE}"