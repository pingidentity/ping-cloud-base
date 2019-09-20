#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

# admin URLs
testUrl ${PINGACCESS_CONSOLE}
testUrl ${PINGACCESS_API}

# runtime URL
testUrl ${PINGACCESS_RUNTIME}/anything
testUrl ${PINGACCESS_AGENT}