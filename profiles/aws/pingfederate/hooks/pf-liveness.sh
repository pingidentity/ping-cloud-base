#!/usr/bin/env sh

function parse_http_response_code() {
  printf "${1}"| awk '/HTTP/' | awk '{print $2}'
}

version_endpoint='https://localhost:9999/pf-admin-api/v1/version'
echo "Starting PingFederate liveness probe.  Waiting for Admin API endpoint at ${version_endpoint}"

get_version_response=$(curl -k \
  -s \
  -S \
  -i \
  -u 'Administrator':${PF_ADMIN_USER_PASSWORD} \
  -H 'X-Xsrf-Header: PingFederate' \
  "${version_endpoint}")
exit_code=$?

get_version_response_code=$(parse_http_response_code "${get_version_response}")

if test ${exit_code} -eq 0 && test 200 -eq ${get_version_response_code}; then
  echo "PingFederate Admin API endpoint version ready"
  exit 0
else
  echo "PingFederate Admin API endpoint version not ready"
  exit 1
fi


