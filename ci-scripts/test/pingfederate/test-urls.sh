#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

testUrl ${PINGFEDERATE_CONSOLE}
testUrl ${PINGFEDERATE_OAUTH_PLAYGROUND}