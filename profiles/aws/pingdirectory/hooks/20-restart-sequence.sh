#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook is called when the container has been built in a prior startup
#- and a configuration has been found.
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../pingdatacommon/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

echo "Restarting container"

# if this hook is provided it can be executed early on
run_hook "21-update-server-profile.sh"

# TODO - See the TODO in pingdata.lib.sh

certificateOptions=$( getCertificateOptions )


#
# If we are RESTARTing the server, we will need to copy any
# keystore/truststore certificate and pin files to the
# pd.profile if they aren't already set.  This implies that
# the server used those keystore/trustore files initially to
# setup the server

echo "Copying existing certificate files from existing install..."
for _certFile in keystore truststore ; do
    if test -f "${SERVER_ROOT_DIR}/config/${_certFile}" -a ! -f "${PD_PROFILE}/server-root/pre-setup/config/${_certFile}" ; then
        echo "  ${SERVER_ROOT_DIR}/config/${_certFile} ==>"
        echo "    ${PD_PROFILE}/server-root/pre-setup/config/${_certFile}"

        cp -af "${SERVER_ROOT_DIR}/config/${_certFile}" \
           "${PD_PROFILE}/server-root/pre-setup/config/${_certFile}"
    else
        echo "  ${_certFile} not found in existing install or was found in pd.profile"
    fi
done

echo "Copying existing certificate pin files from existing install..."
for _pinFile in keystore.pin truststore.pin ; do
    if test -f "${SERVER_ROOT_DIR}/config/${_pinFile}" -a ! -f "${PD_PROFILE}/server-root/pre-setup/config/${_pinFile}" ; then
        echo "  ${SERVER_ROOT_DIR}/config/${_pinFile} ==>"
        echo "    ${PD_PROFILE}/server-root/pre-setup/config/${_pinFile}"

        "${SERVER_ROOT_DIR}"/bin/encrypt-file --decrypt \
            --input-file "${SERVER_ROOT_DIR}/config/${_pinFile}" \
            --output-file "${PD_PROFILE}/server-root/pre-setup/config/${_pinFile}"
    else
        echo "  ${_pinFile} not found in existing install or was found in pd.profile"
    fi
done


# echo "  ${SERVER_ROOT_DIR}/config/encryption-settings.pin ==>"
# echo "    ${PD_PROFILE}/server-root/pre-setup/config/encryption-settings.pin"
# cp -af "${SERVER_ROOT_DIR}/config/encryption-settings.pin" \
#   "${PD_PROFILE}/server-root/pre-setup/config/encryption-settings.pin"


# echo "  ${SERVER_ROOT_DIR}/config/encryption-settings ==>"
# echo "    ${PD_PROFILE}/server-root/pre-setup/config/encryption-settings"
# cp -af "${SERVER_ROOT_DIR}/config/encryption-settings" \
#   "${PD_PROFILE}/server-root/pre-setup/config/encryption-settings"

encryptionOption=$( getEncryptionOption )

jvmOptions=$( getJvmOptions )

export certificateOptions encryptionOption jvmOptions

echo "Checking license file..."
_currentLicense="${LICENSE_DIR}/${LICENSE_FILE_NAME}"
_pdProfileLicense="${STAGING_DIR}/pd.profile/server-root/pre-setup/${LICENSE_FILE_NAME}"
if test ! -f "${_pdProfileLicense}" ; then
    echo "Copying in license from existing install."
    echo "  ${_currentLicense} ==> "
    echo "    ${_pdProfileLicense}"
    cp -af "${_currentLicense}" "${_pdProfileLicense}"
fi

echo "Merging changes from new server profile..."

if test -f "${STAGING_DIR}/env_vars"  ; then
    _manageProfileOptions="--profileVariablesFile ${STAGING_DIR}/env_vars "
fi

# Give manage-profile and the tools it invokes internally all of the available memory to do their processing
ORIG_UNBOUNDID_JAVA_ARGS=${UNBOUNDID_JAVA_ARGS}
export UNBOUNDID_JAVA_ARGS="-client -Xmx${MAX_HEAP_SIZE} -Xms${MAX_HEAP_SIZE}"

"${SERVER_BITS_DIR}"/bin/manage-profile replace-profile \
        --serverRoot "${SERVER_ROOT_DIR}" \
        --profile "${STAGING_DIR}/pd.profile" \
        ${_manageProfileOptions} --useEnvironmentVariables \
        --reimportData never

export UNBOUNDID_JAVA_ARGS=${ORIG_UNBOUNDID_JAVA_ARGS}

MANAGE_PROFILE_STATUS=${?}
echo "manage-profile replace-profile status: ${MANAGE_PROFILE_STATUS}"

test "${MANAGE_PROFILE_STATUS}" -ne 0 && exit 20

run_hook "185-apply-tools-properties.sh"
exit 0