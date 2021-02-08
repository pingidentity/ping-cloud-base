#!/usr/bin/env sh
#
# This hook flushes the work directory of the app server work directory used
# to explode wars for running. Normally the application server cleans up
# after itself, but if it crashes, cleanup fails.
#
${VERBOSE} && set -x
. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"
wd=$(pwd)
beluga_log "Cleaning up stale work directories in ${SERVER_ROOT_DIR}/work"
cd ${SERVER_ROOT_DIR}/work && rm -rfv * && cd ${wd}
exit 0
