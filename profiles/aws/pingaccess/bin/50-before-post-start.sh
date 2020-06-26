#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"

echo "OPERATIONAL_MODE:"${OPERATIONAL_MODE}

if test ! -z "${OPERATIONAL_MODE}" && test "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"; then
  sh "${HOOKS_DIR}/51-add-engine.sh"
  if test $? -ne 0; then
    exit 1
  fi
fi