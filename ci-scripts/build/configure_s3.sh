#!/bin/sh
SCRIPT_HOME=$(
    cd $(dirname ${0})
    pwd
)
. "${SCRIPT_HOME}"/../../common.sh

# Configure aws and kubectl, unless skipped
configure_aws
