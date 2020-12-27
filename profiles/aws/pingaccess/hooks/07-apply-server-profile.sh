#!/usr/bin/env sh
#
# After researching how the GTE default server profile mechanism works, I've concluded it doesn't. In fact
# it is a total cluster... Looking at entrypoint.sh it lays down the local profile first then overlays it 
# with the remote profile. It does this because it's the only way to override the 01-server-start.sh hook 
# but then in 21-update-server-profile.sh it lays down the remote profile and overlays it with the local 
# profile so on START the remote profile has precedence but on RESTART the local profile takes precedence. 
# Additionally on START the local profile is subject to variable substitution because it is merged prior to
# calling 05-expand-templates.sh but on RESTART it not because there is no call to 05-expand-templates.sh 
# at all. 
# 
# This custom version of the 07-apply-profile.sh hook will replace the orignal 07-apply-profile.sh and 
# 21-update-server-profile.sh to try to address this and enforce consistent behavior for both start and
# restart run plans. This change enforces giving precedence to the local profile over the remote one. To do 
# this it will reapply the local profile over the staging area and recall the 05-expand-templates.sh
# 
# There will still be a slight discrepancy in that on start templates will already have been expanded once
# but provided the variable values do not change between calls the process should be idempotent. 
#
# START / RESTART Processing:
#
#  None of the data in the PingAccess server profile is modifiable via the UI/API so applying the Server 
#  Profile should be idempotent unless a change is made. In this case it is safe to explicitly apply the 
#  server profile on all runs. In addition to addressing the issue described above bypassing the use of  
#  the SERVER_PROFILE_UPDATE flag is operationally simpler and unambiguous. 

${VERBOSE} && set -x

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

#
# Reapply the local profile to ensure it has precedence over the remote profile.
#
apply_local_server_profile
#
# Apply template expansion in case local profile has templated files, these will not have been expanded
# yet on a RESTART run.
#
run_hook 05-expand-templates.sh
#
# We chould now have the server profile in a consistent state on both START & RESTART runs, apply it
#

if test -d "${STAGING_DIR}/instance" && find "${STAGING_DIR}/instance" -type f | read -r
then
    echo "merging ${STAGING_DIR}/instance to ${SERVER_ROOT_DIR}"
    copy_files "${STAGING_DIR}/instance" "${SERVER_ROOT_DIR}"
fi

