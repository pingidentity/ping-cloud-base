#!/bin/sh

. "${HOOKS_DIR}/pingcommon.lib.sh"

_curDir=$(dirname $0)

run_hook "91-post-start.sh" $_curDir

run_hook "92-import-initial-configuration.sh" $_curDir