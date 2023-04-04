#!/bin/bash

. "${PROJECT_DIR}"/tests/pingaccess/util/pa-test-utils.sh
. "${PROJECT_DIR}"/tests/pingaccess/common-api/log-response.sh

get_entity() {

  password="${1}"
  endpoint="${2}"
  type="${3}"

  response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    "${endpoint}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  response_code=$(parse_http_response_code "${response}")
  log_response ${response_code} "${response}" "There was a problem get an entity:"

  return $?
}

get_site() {

  password="${1}"
  id="${3}"
  endpoint="${2}/sites/${id}"

  get_site_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    "${endpoint}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  get_site_response_code=$(parse_http_response_code "${get_site_response}")
  log_response ${get_site_response_code} "${get_site_response}" "There was a problem getting the site:"

  return $?
}

get_virtual_host() {

  password="${1}"
  id="${3}"
  endpoint="${2}/virtualhosts/${id}"

  get_virtual_host_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    "${endpoint}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  get_virtual_host_response_code=$(parse_http_response_code "${get_virtual_host_response}")
  log_response ${get_virtual_host_response_code} "${get_virtual_host_response}" "There was a problem getting the virtual host:"

  return $?
}

get_application() {

  password="${1}"
  id="${3}"
  endpoint="${2}/applications/${id}"

  get_application_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    "${endpoint}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  get_application_response_code=$(parse_http_response_code "${get_application_response}")
  log_response ${get_application_response_code} "${get_application_response}" "There was a problem getting the application:"

  return $?
}

get_web_session() {

  password="${1}"
  id="${3}"
  endpoint="${2}/webSessions/${id}"

  get_web_session_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    "${endpoint}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  get_web_session_response_code=$(parse_http_response_code "${get_web_session_response}")
  log_response ${get_web_session_response_code} "${get_web_session_response}" "There was a problem getting the web session:"

  return $?
}

get_ping_one() {

  password="${1}"
  endpoint="${2}/pingone/customers"

  get_ping_one_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    "${endpoint}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  get_ping_one_response_code=$(parse_http_response_code "${get_ping_one_response}")
  log_response ${get_ping_one_response_code} "${get_ping_one_response}" "There was a problem getting the ping one configuration:"

  return $?
}

get_token_provider() {

  password="${1}"
  endpoint="${2}/tokenProvider/settings"

  get_token_provider_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    "${endpoint}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  get_token_provider_response_code=$(parse_http_response_code "${get_token_provider_response}")
  log_response ${get_token_provider_response_code} "${get_token_provider_response}" "There was a problem getting the token provider configuration:"

  return $?
}