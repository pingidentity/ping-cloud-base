#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

testUrls ${PROMETHEUS} ${GRAFANA}
exit ${?}