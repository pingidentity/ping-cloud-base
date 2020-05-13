#!/bin/bash

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

. ${SCRIPT_HOME}/../pingaccess/util/pa_test_utils

PA_ADMIN_PASSWORD=${PA_ADMIN_PASSWORD:-2FederateM0re}

kubectl delete pod pingaccess-admin-0 -n "${NAMESPACE}"

echo "Waiting for admin server at ${PINGACCESS_API}/applications"

set +x
for i in {1..5}
do
  # Call to a real endpoint to verify
  # PA is up
  response=$(curl -k \
                  -i \
                  -s \
                  -u "Administrator:${PA_ADMIN_PASSWORD}" \
                  -H 'X-Xsrf-Header: PingAccess' \
                  "${PINGACCESS_API}/applications")

  response_code=$(parse_http_response_code "${response}")

  if [[ 200 -ne ${response_code} ]]; then
    echo "Admin server not started, waiting.."
    sleep 15
  else
    echo "Admin server successfully restarted"
    exit 0
  fi
done

echo "Could not verify the PA admin console came back up after the pod was deleted"
exit 1
