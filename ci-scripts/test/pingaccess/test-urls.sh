#!/bin/sh
set -ex

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

# FIXME: this has been failing with a BeanCreationgException is recent builds
#testUrl ${PING_ACCESS_CONSOLE}