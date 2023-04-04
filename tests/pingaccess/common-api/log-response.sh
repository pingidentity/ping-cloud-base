#!/bin/bash

log_response() {
  local response_code=$1
  local response="${2}"
  local error_message="${3}"

  if [[ 200 -eq ${response_code} ]]; then
    # This echo is not for debugging.  It's meant to push
    # the response data to stdout for the caller.
    echo "${response}"
    return 0
  else
    # These messages won't be printed to stdout
    # until the top level caller echoes them.
    echo "${error_message}"
    echo "${response}"
    return 1
  fi
}

log_curl_exit() {
  curl_exit_code=${1}
  endpoint=${2}

  if [[ ${curl_exit_code} -ne 0 ]]; then
    # These messages won't be printed to stdout
    # until the top level caller echoes them.
    echo "ERROR: The curl call to ${endpoint} returned the exit code: ${curl_exit_code}"
    return ${curl_exit_code}
  fi
}