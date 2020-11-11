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
# In adition to addressing the issue outlined above this custom hook enforces behavior specific to 
# PingFederate. The path ${SERVER_ROOT_DIR}/server/default/data contains files that we need to treat as data
# to be modified only through the application most of the time but in order to pre-wire PingFederate to 
# Pingdirectory for authentication we need to set an initial state for these files that should be treated as 
# configuration. This is a convenience for professional services/support to help minimize the manual 
# intervention needed to create a new environment. In essence we're treating the ./server/default/data 
# directory as configuration on the first launch of an environment and as data in all other cases. 
#
# START Processing:
#
#  During execution of the START run plan the full server profile is applied, for a new environment this
#  will act as a 'bootstrap' profile as there will not be a S3 backup to restore. In the case of an existing
#  environment where we're recreating the persistent volume an S3 backup will exist and files laid down 
#  under ${SERVER_ROOT_DIR}/server/default/data will be overwritten by the backup restore step later in the
#  sequence.
#
# RESTART Processing:
#
#  In this case we do not perform a data restore since the persistent volume already has the data on it.
#  And if we apply data from the server profile we will potentially overwrite changes made through the UI
#  or API resulting in the loss of customer data. To avoid this we consider this directory as data rather
#  than configuration and remove it prior to applying the server profile. 
#

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
    if test "${RUN_PLAN}" = "START"
    then
        echo "merging ${STAGING_DIR}/instance to ${SERVER_ROOT_DIR}"
    else
        echo "merging ${STAGING_DIR}/instance to ${SERVER_ROOT_DIR}, ./server/default/data directory excluded"
        rm -rf ${STAGING_DIR}/instance/server/default/data
    fi
    copy_files "${STAGING_DIR}/instance" "${SERVER_ROOT_DIR}"
fi

