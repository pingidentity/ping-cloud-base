#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"

echo "OPERATIONAL_MODE:"${OPERATIONAL_MODE}

if test ! -z "${OPERATIONAL_MODE}" && test "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"; then
  run_hook "51-add-engine.sh"
fi