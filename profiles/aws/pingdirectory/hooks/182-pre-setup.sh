#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdirectory.lib.sh
test -f "${HOOKS_DIR}/pingdirectory.lib.sh" && . "${HOOKS_DIR}/pingdirectory.lib.sh"

#
# Override headless service validation of allowing unready hosts.
# This validation can be found within the original hook script of docker image.
# Due to offline replication support in PingCloud and issue with PDO- , we can override.
#
echo "Override docker image hook that validates headless service allowing unready hosts" 

#
# If we are the GENESIS state, then process any templates if they are defined.
#

if test "${PD_STATE}" = "GENESIS" ;
then
    echo "PD_STATE is GENESIS ==> Processing Templates"

    test -z "${MAKELDIF_USERS}" && MAKELDIF_USERS=0

    find "${PD_PROFILE}/ldif" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | while read _ldifDir
        do
        find "${_ldifDir}" -type f -iname \*.template 2>/dev/null | while read _template
        do
            echo "Processing (${_template}) template with ${MAKELDIF_USERS} users..."
            _generatedLdifFilename="${_template%.*}.ldif"
            "${SERVER_ROOT_DIR}/bin/make-ldif" \
                --templateFile "${_template}"  \
                --ldifFile "${_generatedLdifFilename}" \
                --numThreads 3
        done
    done
else
    echo "PD_STATE is not GENESIS ==> Skipping Templates"
    echo "PD_STATE is not GENESIS ==> Will not process ldif imports"

    # GDO-191 - Following is used by 183-run-setup.sh.  Appended to CONTAINER_ENV, to allow for that
    # hook to pick it up
    _skipImports="--skipImportLdif"

    # next line is for shellcheck disable to ensure $RUN_PLAN is used
    echo "${_skipImports}" >> /dev/null

    export_container_env _skipImports
fi

appendTemplatesToVariablesIgnore