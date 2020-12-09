#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

currentDir="$(pwd)"
cd "${SERVER_ROOT_DIR}/conf"

JVM_MEM_OPTS_FILE='jvm-memory.options'
JVM_MEM_OPTS_FILE_BAK="${JVM_MEM_OPTS_FILE}.bak"

JVM_VARS='${PA_MIN_HEAP}
${PA_MAX_HEAP}
${PA_MIN_YGEN}
${PA_MAX_YGEN}
${PA_GCOPTION}'

mv "${JVM_MEM_OPTS_FILE}" "${JVM_MEM_OPTS_FILE_BAK}"
envsubst "${JVM_VARS}" \
    < "${STAGING_DIR}/instance/conf/${JVM_MEM_OPTS_FILE}" \
    > "${JVM_MEM_OPTS_FILE}"

beluga_log "contents of jvm-memory.options after substitution:"
cat "${JVM_MEM_OPTS_FILE}"

cd "${currentDir}"