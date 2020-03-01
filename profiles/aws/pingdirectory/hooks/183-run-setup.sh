#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

export certificateOptions=$(getCertificateOptions)
export encryptionOption=$(getEncryptionOption)
export jvmOptions=$(getJvmOptions)

# Give manage-profile and the tools it invokes internally all of the available memory to do their processing
ORIG_UNBOUNDID_JAVA_ARGS=${UNBOUNDID_JAVA_ARGS}
export UNBOUNDID_JAVA_ARGS="-client -Xmx${MAX_HEAP_SIZE} -Xms${MAX_HEAP_SIZE}"

"${SERVER_ROOT_DIR}"/bin/manage-profile setup \
    --profile "${PD_PROFILE}" \
    --useEnvironmentVariables \
    --tempProfileDirectory /tmp \
    --doNotStart \
    --rejectFile /tmp/rejects.ldif

export UNBOUNDID_JAVA_ARGS=${ORIG_UNBOUNDID_JAVA_ARGS}

MANAGE_PROFILE_STATUS=${?}
echo "manage-profile setup status: ${MANAGE_PROFILE_STATUS}"

if test "${MANAGE_PROFILE_STATUS}" -ne 0; then
  test -f /tmp/rejects.ldif && cat /tmp/rejects.ldif
  exit 183
fi