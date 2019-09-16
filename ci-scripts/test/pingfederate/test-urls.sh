#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

# admin URLs
testUrl ${PINGFEDERATE_CONSOLE}
testUrl ${PINGFEDERATE_API}

# runtime URLs
testUrl ${PINGFEDERATE_OAUTH_PLAYGROUND}