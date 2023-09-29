#!/usr/bin/env bash

set -e

test "${VERBOSE}" && set -x

errors=()

function docker_command() {
  HOME=/tmp docker "${@:1}"
}

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

deploy_file=/tmp/deploy.yaml
build_dev_deploy_file "${deploy_file}"

kubescape scan "${deploy_file}"