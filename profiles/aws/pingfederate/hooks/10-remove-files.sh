#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"
. "${HOOKS_DIR}/util/delete-file-utils.sh"

"${VERBOSE}" && set -x

# PDO-2609 - Remove pf-referenceid-adapter-2.0.1
delete_file "${SERVER_ROOT_DIR}"/server/default/deploy/pf-referenceid-adapter-2.0.1.jar

exit 0