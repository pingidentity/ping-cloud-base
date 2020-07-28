#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

TEMPLATES_DIR_PATH=${STAGING_DIR}/templates/83
ENDPOINT="https://localhost:9000/pa-admin-api/v3"

create_web_session() {
  local web_session_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/web-session-payload.json)
  local resource=webSessions

  echo "configure-pa-was: Creating Web Session"
  set +x  # Hide P14C client secret in logs
  create_entity "${web_session_payload}" "${resource}"
  "${VERBOSE}" && set -x
}

create_pa_virtual_host() {
  export VHOST_ID=10
  export VHOST_HOST="${PA_ADMIN_PUBLIC_HOSTNAME}"
  export VHOST_PORT=443

  echo "configure-pa-was: Creating PA Virtual Host"
  create_virtual_host
}

create_pf_virtual_host() {
  export VHOST_ID=20
  export VHOST_HOST="${PF_ADMIN_PUBLIC_HOSTNAME}"
  export VHOST_PORT=443

  echo "configure-pa-was: Creating PF Virtual Host"
  create_virtual_host
}

create_virtual_host() {
  local vhost_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/vhost-payload.json)
  local resource=virtualhosts

  create_entity "${vhost_payload}" "${resource}"
  unset VHOST_ID VHOST_HOST VHOST_PORT
}

create_pa_site() {
  export SITE_ID=10
  export SITE_NAME="PingAccess Admin Console"
  export SITE_TARGET="pingaccess-admin:9000"

  echo "configure-pa-was: Creating PA Site"
  create_site
}

create_pf_site() {
  export SITE_ID=20
  export SITE_NAME="PingFederate Admin Console"
  export SITE_TARGET="pingfederate-admin:9999"

  echo "configure-pa-was: Creating PF Site"
  create_site
}

create_site() {
  local site_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/site-payload.json)
  local resource=sites

  create_entity "${site_payload}" "${resource}"
  unset SITE_ID SITE_NAME SITE_TARGET
}

create_pa_application() {
  export APP_ID=10
  export APP_NAME="PingAccess App"
  export APP_DESCRIPTION="PingAccess Web Application"
  export VIRTUAL_HOST_ID=10
  export SITE_ID=10

  echo "configure-pa-was: Creating PA Application"
  create_application
}

create_pf_application() {
  export APP_ID=20
  export APP_NAME="PingFederate App"
  export APP_DESCRIPTION="PingFederate Web Application"
  export VIRTUAL_HOST_ID=20
  export SITE_ID=20

  echo "configure-pa-was: Creating PF Application"
  create_application
}

create_application() {
  if is_production_environment; then
    export SESSION_ID=10
  else
    export SESSION_ID=0
  fi

  local app_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/application-payload.json)
  local resource=applications

  create_entity "${app_payload}" "${resource}"
  unset APP_ID APP_NAME APP_DESCRIPTION VIRTUAL_HOST_ID SITE_ID SESSION_ID
}

create_entity() {
  local payload="${1}"
  local resource="${2}"

  echo "configure-pa-was: make_api_request response..."
  make_api_request -s -X POST -d "${payload}" "${ENDPOINT}"/"${resource}"
}

is_production_environment() {
  test "${ENVIRONMENT_TYPE}"
}


create_web_session
create_pa_virtual_host
create_pf_virtual_host
create_pa_site
create_pf_site
create_pa_application
create_pf_application

echo "configure-pa-was: Configuration complete"