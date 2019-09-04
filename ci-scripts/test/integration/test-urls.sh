#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

# FIXME: since the elastic stack is just deployed once on the shared cluster,
# this URL will change as soon as a new branch is cut. Uncomment the test once
# this is fixed.
# testUrl ${LOGS_CONSOLE}