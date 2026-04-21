#!/bin/bash

. "${CI_SCRIPTS_DIR}"/test/test_utils.sh

secret_data=$(kubectl get secret -n ping-cloud pingfederate-admin-p14c -o jsonpath='{.data}')
client_id=$(echo "${secret_data}" | jq -r '."PF_OIDC_CLIENT_ID"' | base64 --decode)
client_secret=$(echo "${secret_data}" | jq -r '."PF_OIDC_CLIENT_SECRET"' | base64 --decode)
issuer=$(echo "${secret_data}" | jq -r '."PF_OIDC_ISSUER"' | base64 --decode)
token_url="${issuer}/token"
if ! TOKEN=$(get_token "${client_id}" "${client_secret}" "${token_url}" "p1asPFOperatorRoles") 2>/tmp/token_err; then
  echo "Failed to retrieve token for API access: $(cat /tmp/token_err)"
  exit 1
fi

export TOKEN