#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

MASTER_KEY_PATH="${SERVER_ROOT_DIR}/conf/pa.jwk"

JWK_ENCRYPTED=false

if test -f "${MASTER_KEY_PATH}"; then
  res=$(cat "${MASTER_KEY_PATH}" | jq "" 2>/dev/null)
  rc=$?
  if test $rc -ne 0; then
    JWK_ENCRYPTED=true
  fi
fi
   
substitute_kms_key_id $JWK_ENCRYPTED
