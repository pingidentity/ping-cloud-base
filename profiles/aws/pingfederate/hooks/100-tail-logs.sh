#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

beluga_log "Tailing logs: ${K8S_TAIL_LOG_FILES}"
beluga_log "Changes are here!"

for K8_LOG_FILE in ${K8S_TAIL_LOG_FILES}; do
  tail -F ${K8_LOG_FILE}  | awk -v log_file="${K8_LOG_FILE} " '{ print log_file$0 }' &
done
