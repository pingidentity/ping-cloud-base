#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

export certificateOptions=$(getCertificateOptions)
export encryptionOption=$(getEncryptionOption)
export jvmOptions=$(getJvmOptions)

"${SERVER_ROOT_DIR}"/bin/manage-profile setup \
    --profile "${PD_PROFILE}" \
    --useEnvironmentVariables \
    --tempProfileDirectory /tmp \
    --doNotStart \
    --rejectFile /tmp/rejects.ldif

if test $? -ne 0; then
  test -f /tmp/rejects.ldif && cat /tmp/rejects.ldif
  exit 183
fi