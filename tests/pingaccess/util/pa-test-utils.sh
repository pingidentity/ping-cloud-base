#!/bin/bash

function parse_http_response_code() {
  set +x
  printf "${1}"| head -n 1 | awk '/HTTP/' | awk '{print $2}'
}

function parse_value_from_response() {
  set +x
  local json=$(printf "${1}" | awk '/\{.*\}/')
  jq -n "${json}" | jq --arg pattern "${2}" '.[$pattern]'
}

function parse_value_from_array_response() {
  set +x
  local json=$(printf "${1}" | awk '/\{.*\}/')
  jq -n "${json}" | jq '.items' | jq '.[]' | jq --arg pattern "${2}" '.[$pattern]'
}

function strip_double_quotes() {
  temp="${1%\"}"
  temp="${temp#\"}"
  echo ${temp}
}

# PA-WAS uses this method and needs basic auth
curl_auth_header() {
  local password="${1}"
  local token="${2}"
  if [[ -n "${token}" ]]; then
    echo "Authorization: Bearer ${token}"
  else
    echo "Authorization: Basic $(echo -n "Administrator:${password}" | base64)"
  fi
}