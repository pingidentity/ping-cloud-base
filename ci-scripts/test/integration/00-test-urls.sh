#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

testUrls ${LOGS_CONSOLE} ${PROMETHEUS} ${GRAFANA}
exit ${?}