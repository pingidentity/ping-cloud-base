#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

testUrl ${PINGFEDERATE_CONSOLE} ${PINGFEDERATE_API} ${PINGFEDERATE_OAUTH_PLAYGROUND}
exit ${?}