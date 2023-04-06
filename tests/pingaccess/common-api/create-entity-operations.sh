#!/bin/bash

. "${PROJECT_DIR}"/tests/pingaccess/util/pa-test-utils.sh
. "${PROJECT_DIR}"/tests/pingaccess/common-api/log-response.sh


create_shared_secret() {
  set +x
  password="${1}"
  endpoint="${2}/sharedSecrets"

  # export for envsubst
  export AGENT_SHARED_SECRET="${3}" # shared secrets must be 22 chars

  create_shared_secret_payload=$(envsubst < ${templates_dir_path}/create-shared-secret-payload.json)
  create_shared_secret_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    -d "${create_shared_secret_payload}" \
    "${endpoint}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  # Clean up
  unset AGENT_SHARED_SECRET

  create_shared_secret_response_code=$(parse_http_response_code "${create_shared_secret_response}")
  log_response ${create_shared_secret_response_code} "${create_shared_secret_response}" "There was a problem creating a shared secret:"

  return $?
}


create_agent() {

  set +x

  password="${1}"
  endpoint="${2}/agents"

  # export for envsubst
  export SHARED_SECRET_ID=${3}
  export PA_ENGINE_HOST=${4}

  create_agent_payload=$(envsubst < ${templates_dir_path}/create-agent-payload.json)
  create_agent_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    -d "${create_agent_payload}" \
    "${endpoint}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  # Clean up
  unset SHARED_SECRET_ID
  unset PA_ENGINE_HOST

  create_agent_response_code=$(parse_http_response_code "${create_agent_response}")
  log_response ${create_agent_response_code} "${create_agent_response}" "There was a problem creating an agent:"

  return $?
}

create_site_application() {

  set +x

  password="${1}"
  endpoint="${2}/applications"

  create_application_payload=$(envsubst < ${templates_dir_path}/create-site-application-payload.json)
  create_application_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    -d "${create_application_payload}" \
    "${endpoint}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  # Clean up
  unset APP_ID APP_NAME VIRTUAL_HOST_ID SITE_ID

  create_application_response_code=$(parse_http_response_code "${create_application_response}")
  log_response ${create_application_response_code} "${create_application_response}" "There was a problem creating an application with the payload: ${create_application_payload}:"

  return $?

}

create_agent_application() {

  set +x

  password="${1}"
  endpoint="${2}/applications"

  # export for envsubst
  export AGENT_ID=${3}
  export VIRTUAL_HOST_ID=${4}

  create_application_payload=$(envsubst < ${templates_dir_path}/create-agent-application-payload.json)
  create_application_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    -d "${create_application_payload}" \
    "${endpoint}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  # Clean up
  unset AGENT_ID
  unset VIRTUAL_HOST_ID

  create_application_response_code=$(parse_http_response_code "${create_application_response}")
  log_response ${create_application_response_code} "${create_application_response}" "There was a problem creating an application with the payload: ${create_application_payload}:"

  return $?
}


create_virtual_host() {

  set +x

  password="${1}"
  endpoint="${2}/virtualhosts"

  create_vhost_payload=$(envsubst < ${templates_dir_path}/create-vhost-payload.json)
  create_vhost_response=$(curl -k \
    -i \
    -s \
    -u "Administrator:${password}" \
    -H 'X-Xsrf-Header: PingAccess' \
    -d "${create_vhost_payload}" \
    "${endpoint}")

  log_curl_exit $? "${endpoint}"
  exit_code=$?
  test ${exit_code} -ne 0 && return ${exit_code}

  create_vhost_response_code=$(parse_http_response_code "${create_vhost_response}")
  log_response ${create_vhost_response_code} "${create_vhost_response}" "There was a problem creating a virtual host:"

  return $?
}
