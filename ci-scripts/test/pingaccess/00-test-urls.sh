#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

testUrls ${PINGACCESS_CONSOLE} ${PINGACCESS_API} ${PINGACCESS_AGENT} ${PINGACCESS_RUNTIME}/anything
exit ${?}