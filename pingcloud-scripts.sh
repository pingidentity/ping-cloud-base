#!/bin/bash

# NOTE: If this file is updated ANYWHERE, it must be updated across ALL repos
# TODO: Figure out a way to not have this duplicated as well (but something needs to bootstrap the source...)

########################################################################################################################
# pingcloud-scripts::source_script - Sources a given script and version from S3 or locally from the
#   ping-cloud-common/pingcloud-scripts repo/directory
# Arguments:
# $1 - name - the name of the script to source
# $2 - version - the version of the script to source
# $3 - aws_profile - optional - the AWS_PROFILE to use
########################################################################################################################
pingcloud-scripts::source_script() {
    local script_name="${1}"
    local version="${2}"
    local aws_profile="${3:-${AWS_PROFILE}}"
    local usage="pingcloud-scripts::source_script SCRIPT_NAME VERSION [aws_profile]"

    if [[ "${LOCAL}" == "true" ]]; then
        # NOTE: You must set LOCAL and the location for PCC_PATH to enable local testing
        source "${PCC_PATH}/pingcloud-scripts/${script_name}/${script_name}.sh"
        return 0
    fi

    if [[ $# -lt 2 ]]; then
        echo "Too few arguments provided. Usage: ${usage}"
        return 1
    fi

    local tmp_dir="/tmp/pingcloud-scripts/${version}"
    local src_bucket="pingcloud-scripts"

    # If not a version of format x.x.x, assume it's in dev s3 bucket
    if [[ ! "${version}" =~ ^[0-9]+.[0-9]+.[0-9]+$ ]]; then
        src_bucket="pingcloud-scripts-dev"
    fi

    mkdir -p "${tmp_dir}"

    # File already exists, don't copy every time (for same version - tmp_dir contains version)
    # NOTE: if you need to purge the 'cache', delete the file to force pull from S3
    if [[ -f "${tmp_dir}/${script_name}.sh" ]]; then
        source "${tmp_dir}/${script_name}.sh"
        return 0
    fi

    if ! aws --no-cli-pager --profile "${aws_profile}" sts get-caller-identity > /dev/null 2>&1; then
        echo "pingcloud-scripts::source_script - Make sure you are logged into a current AWS session!"
        return 1
    fi

    aws --profile "${aws_profile}" --only-show-errors s3 cp \
        "s3://${src_bucket}/${script_name}/${version}/${script_name}.tar.gz" "${tmp_dir}/${script_name}.tar.gz"

    tar -xzf "${tmp_dir}/${script_name}.tar.gz" -C "${tmp_dir}"
    source "${tmp_dir}/${script_name}.sh"
}
