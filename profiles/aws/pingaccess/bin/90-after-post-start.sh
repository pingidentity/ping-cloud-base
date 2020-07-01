#!/bin/sh

. "${HOOKS_DIR}/pingcommon.lib.sh"

_curDir=$(dirname $0)

run_hook "91-post-start-init.sh" $_curDir
