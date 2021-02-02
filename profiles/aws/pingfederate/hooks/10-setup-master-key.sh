#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

#---------------------------------------------------------------------------------------------
# Main Script
#---------------------------------------------------------------------------------------------

#
# We may already have a master key on disk if one was supplied through a secret, the 'in' volume or
# extracted from a backup in the drop in deployer directory; in these cases we will use that key
# during obfuscation.
#

MASTER_KEY_PATH="${SERVER_ROOT_DIR}/server/default/data/pf.jwk"
if ! test -f "${MASTER_KEY_PATH}"; then
  beluga_log "No pre-existing master key found - obfuscate will create one"
else
  beluga_log "A pre-existing master key was found on disk - using it"
fi

obfuscatePassword
