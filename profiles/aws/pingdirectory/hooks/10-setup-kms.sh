#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

APP_VARS='${KMS_KEY_ARN}
        ${AWS_REGION}'

envsubst "${APP_VARS}" \
    < "${STAGING_DIR}/pd.profile/dsconfig/02-enable-kms.dsconfig.tmpl" \
    > "${STAGING_DIR}/pd.profile/dsconfig/02-enable-kms.dsconfig"
