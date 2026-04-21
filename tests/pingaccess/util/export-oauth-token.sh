#!/bin/bash

. "${CI_SCRIPTS_DIR}"/test/test_utils.sh

configmap_data=$(kubectl get configmap -n ping-cloud pingaccess-admin-p14c -o jsonpath='{.data}')
secret_data=$(kubectl get secret -n ping-cloud pingaccess-admin-p14c -o jsonpath='{.data}')
client_id=$(echo "${configmap_data}" | jq -r '."P14C_CLIENT_ID"')
client_secret=$(echo "${secret_data}" | jq -r '."P14C_CLIENT_SECRET"' | base64 --decode)
issuer=$(echo "${configmap_data}" | jq -r '."P14C_ISSUER"')
token_url="${issuer}/token"
if ! TOKEN=$(get_token "${client_id}" "${client_secret}" "${token_url}" "p1asPAOperatorRoles") 2>/tmp/token_err; then
  echo "Failed to retrieve token for API access: $(cat /tmp/token_err)"
  exit 1
fi

export TOKEN