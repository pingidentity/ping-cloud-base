#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

_COMMON_ARGS="-cacerts \
 -storepass changeit \
 -noprompt"


keytool -list -alias pd-cert ${_COMMON_ARGS}
rc=$?
if [ $rc -eq 0 ]; then # if it exists, delete it so we can re-add it
  keytool -delete -alias pd-cert ${_COMMON_ARGS}
fi

keytool -importcert -alias pd-cert \
  -file /opt/staging/certificates/pd-cert.crt \
  ${_COMMON_ARGS}

