#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

/opt/tools/ldapsearch \
  --hostname ${PINGDIRECTORY_ADMIN} \
  --port 636 \
  --useSSL \
  --trustAll \
  --operationPurpose "LDAP search test from admin subnet with DNS name" \
  --baseDN '' \
  --searchScope base "(&)" 1.1