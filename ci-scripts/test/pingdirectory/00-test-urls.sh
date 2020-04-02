#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. "${SCRIPT_HOME}"/../../common.sh "${1}"

testUrl ${PINGDIRECTORY_CONSOLE}
exit ${?}