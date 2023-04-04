#!/bin/bash

. "${PROJECT_DIR}"/tests/pingaccess/util/pa-test-utils.sh
. "${PROJECT_DIR}"/tests/pingaccess/common-api/log-response.sh

get_virtual_host_by_host_port() {

  set +x

  password="${1}"
  endpoint="${2}"
  host_port="${3}"

  get_virtual_hosts_response=$(curl -k \
    -s \
    -i \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    "${endpoint}/virtualhosts?virtualHost=${host_port}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  get_virtual_hosts_response_code=$(parse_http_response_code "${get_virtual_hosts_response}")
  log_response ${get_virtual_hosts_response_code} "${get_virtual_hosts_response}" "There was a problem getting the virtual host:"

  return $?
}

get_agent_by_name() {

  set +x

  password="${1}"
  endpoint="${2}"
  name="${3}"

  get_agent_response=$(curl -k \
    -s \
    -i \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    "${endpoint}/agents?name=${name}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  get_agent_response_code=$(parse_http_response_code "${get_agent_response}")
  log_response ${get_agent_response_code} "${get_agent_response}" "There was a problem getting the agent:"

  return $?
}

get_application_by_name() {

  set +x

  password="${1}"
  endpoint="${2}"
  name="${3}"

  get_app_response=$(curl -k \
    -s \
    -i \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    "${endpoint}/applications?name=${name}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  get_app_response_code=$(parse_http_response_code "${get_app_response}")
  log_response ${get_app_response_code} "${get_app_response}" "There was a problem getting the application:"

  return $?
}