#!/bin/bash

. "${PROJECT_DIR}"/tests/pingaccess/util/pa-test-utils.sh
. "${PROJECT_DIR}"/tests/pingaccess/common-api/log-response.sh

delete_agent() {

  set +x

  password="${1}"
  endpoint="${2}"
  agent_id="${3}"

  delete_agent_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    -X DELETE \
    "${endpoint}/agents/${agent_id}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  echo "delete_agent: password: ${password}, endpoint: ${endpoint}, agent_id: ${application_id}"
  echo "delete_agent_response: ${delete_agent_response}"

  delete_agent_response_code=$(parse_http_response_code "${delete_agent_response}")
  log_response ${delete_agent_response_code} "${delete_agent_response}" "There was a problem deleting the agent:"

  return $?
}


delete_application() {

  set +x

  password="${1}"
  endpoint="${2}"
  application_id="${3}"

  delete_application_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    -X DELETE \
    "${endpoint}/applications/${application_id}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  echo "delete_application: password: ${password}, endpoint: ${endpoint}, application_id: ${application_id}"
  echo "delete_application_response: ${delete_application_response}"

  delete_application_response_code=$(parse_http_response_code "${delete_application_response}")
  log_response ${delete_application_response_code} "${delete_application_response}" "There was a problem deleting the application:"

  return $?
}


delete_virtual_host() {

  set +x

  password="${1}"
  endpoint="${2}"
  virtual_host_id="${3}"

  delete_virtual_host_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    -X DELETE \
    "${endpoint}/virtualhosts/${virtual_host_id}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  echo "delete_virtual_host values: password: ${password}, endpoint: ${endpoint}, virtual_host_id: ${virtual_host_id}"

  delete_virtual_host_response_code=$(parse_http_response_code "${delete_virtual_host_response}")
  log_response ${delete_virtual_host_response_code} "${delete_virtual_host_response}" "There was a problem deleting the virtual host:"

  return $?
}