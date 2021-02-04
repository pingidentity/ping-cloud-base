#!/usr/bin/env sh
#
# This hook flushes the work directory of the app server work directory used
# to explode wars for running. Normally the application server cleans up
# after itself, but if it crashes, cleanup fails.
#
${VERBOSE} && set -x
. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"
beluga_log "Cleaning up old work directories"
rm -rf "${SERVER_ROOT_DIR}/work/*"
exit 0
