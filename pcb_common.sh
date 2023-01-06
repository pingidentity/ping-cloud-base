#!/bin/bash

pcb_common::source_k8s_utils() {
    local src_bucket="pingcloud-scripts"
    local version="${1:-1.0.0}"
    local aws_profile="${2:-${AWS_PROFILE}}"
    local tmp_dir="/tmp/pcb_common"

    if [[ "${LOCAL}" == "true" ]]; then
        # NOTE: You must set LOCAL and the location for PCC_REPO to enable local testing
        source "${PCC_REPO}/pingcloud-scripts/utils/k8s_utils.sh"
        return
    fi

    # If not a version of format x.x.x, assume it's in dev s3 bucket
    if [[ ! "${version}" =~ ^[0-9]+.[0-9]+.[0-9]+$ ]]; then
        src_bucket="pingcloud-scripts-dev"
    fi

    mkdir -p "${tmp_dir}"

    if ! aws --no-cli-pager --profile "${aws_profile}" sts get-caller-identity > /dev/null 2>&1; then
        echo "Make sure you are logged into a current AWS session!"
        return 1
    fi

    aws --profile "${aws_profile}" --only-show-errors s3 cp \
        "s3://${src_bucket}/utils/${version}/utils.tar.gz" "${tmp_dir}/utils.tar.gz"

    tar -xzf "${tmp_dir}/utils.tar.gz" -C "${tmp_dir}"
    source "${tmp_dir}/k8s_utils.sh"
}