#!/usr/bin/env sh
#
# Make hook a no-op, see the custom version of 07-appply-server-profile.sh for details.
#
${VERBOSE} && set -x
. "${HOOKS_DIR}/pingcommon.lib.sh"

exit 0
