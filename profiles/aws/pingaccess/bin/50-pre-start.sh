#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"

echo "OPERATIONAL_MODE:"${OPERATIONAL_MODE}

run_hook "11-change-default-db-password.sh"

if test ! -z "${OPERATIONAL_MODE}" && test "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"; then
  sh "${MOUNT_DIR}/bin/51-add-engine.sh"
  if test $? -ne 0; then
    exit 1
  fi
fi