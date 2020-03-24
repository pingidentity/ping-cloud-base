#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

# FIXME: re-add httpbin test when server profile is fixed
testUrls ${PINGACCESS_CONSOLE} ${PINGACCESS_API} #${PINGACCESS_RUNTIME}/anything
exit ${?}