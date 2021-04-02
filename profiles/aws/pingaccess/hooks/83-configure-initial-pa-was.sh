#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

TEMPLATES_DIR_PATH=${STAGING_DIR}/templates/83
ENDPOINT="https://localhost:9000/pa-admin-api/v3"

is_previously_configured() {
  local get_applications_response=$(make_api_request "${ENDPOINT}"/applications)
  test $? -ne 0 && return 1

  local applications_count=$(jq -n "${get_applications_response}" | jq '.items | length')

  if test "${applications_count}" -ge 6; then
    beluga_log "pa-was already configured"
    return 0
  else
    return 1
  fi
}

p14c_credentials_changed() {
  get_web_session_clientId

  if test "${PA_WAS_CLIENT_ID}" != "${P14C_CLIENT_ID}"; then
    beluga_log "P14C credentials changed"
    return 0
  else
    beluga_log "P14C credentials unchanged"
    return 1
  fi
}

get_web_session_clientId() {
  local resource=webSessions
  local id=10
  PA_WAS_CLIENT_ID= # Global scope

  beluga_log "Getting Web Session"
  local response=$(get_entity "${resource}" "${id}")
  beluga_log "make_api_request response..."
  beluga_log "${response}"

  PA_WAS_CLIENT_ID=$(jq -n "${response}" | jq '.clientCredentials["clientId"]')
  PA_WAS_CLIENT_ID=$(strip_double_quotes "${PA_WAS_CLIENT_ID}")
}

update_web_session() {
  local web_session_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/web-session-payload.json)
  local resource=webSessions
  local id=10

  beluga_log "Updating Web Session"
  set +x  # Hide P14C client secret in logs
  update_entity "${web_session_payload}" "${resource}" "${id}"
  "${VERBOSE}" && set -x
}

update_application_reserved_endpoint() {
  local application_reserved_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/application-reserved-payload.json)
  local resource='applications/reserved'

  beluga_log "Updating Web Session"
  update_entity "${application_reserved_payload}" "${resource}"
}

create_web_session() {
  local web_session_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/web-session-payload.json)
  local resource=webSessions

  beluga_log "Creating Web Session"
  set +x  # Hide P14C client secret in logs
  create_entity "${web_session_payload}" "${resource}"
  "${VERBOSE}" && set -x
}

create_pa_virtual_host() {
  export VHOST_ID=10
  export VHOST_HOST="${PA_ADMIN_PUBLIC_HOSTNAME}"
  export VHOST_PORT=443

  beluga_log "Creating PingAccess Admin Virtual Host: ${PA_ADMIN_PUBLIC_HOSTNAME}"
  create_virtual_host
}

create_pf_virtual_host() {
  export VHOST_ID=20
  export VHOST_HOST="${PF_ADMIN_PUBLIC_HOSTNAME}"
  export VHOST_PORT=443

  beluga_log "Creating PingFederate Admin Virtual Host: ${PF_ADMIN_PUBLIC_HOSTNAME}"
  create_virtual_host
}

create_kibana_virtual_host() {
  export VHOST_ID=21
  export VHOST_HOST="${KIBANA_PUBLIC_HOSTNAME}"
  export VHOST_PORT=443

  beluga_log "Creating Kibana Virtual Host: ${KIBANA_PUBLIC_HOSTNAME}"
  create_virtual_host
}

create_grafana_virtual_host() {
  export VHOST_ID=22
  export VHOST_HOST="${GRAFANA_PUBLIC_HOSTNAME}"
  export VHOST_PORT=443

  beluga_log "Creating Grafana Virtual Host: ${GRAFANA_PUBLIC_HOSTNAME}"
  create_virtual_host
}

create_prometheus_virtual_host() {
  export VHOST_ID=23
  export VHOST_HOST="${PROMETHEUS_PUBLIC_HOSTNAME}"
  export VHOST_PORT=443

  beluga_log "Creating Prometheus Virtual Host: ${PROMETHEUS_PUBLIC_HOSTNAME}"
  create_virtual_host
}

create_virtual_host() {
  local vhost_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/vhost-payload.json)
  local resource=virtualhosts

  create_entity "${vhost_payload}" "${resource}"
  unset VHOST_ID VHOST_HOST VHOST_PORT
}

create_argocd_virtual_host() {
  export VHOST_ID=24
  export VHOST_HOST="${ARGOCD_PUBLIC_HOSTNAME}"
  export VHOST_PORT=443

  beluga_log "Creating Argo CD Virtual Host: ${ARGOCD_PUBLIC_HOSTNAME}"
  create_virtual_host
}

create_pa_site() {
  export SITE_ID=10
  export SITE_NAME="PingAccess Admin Console"
  export SITE_TARGET="pingaccess-admin:9000"
  export SITE_SECURE=true

  beluga_log "Creating PA Site"
  create_site
}

create_pf_site() {
  export SITE_ID=20
  export SITE_NAME="PingFederate Admin Console"
  export SITE_TARGET="pingfederate-admin:443"
  export SITE_SECURE=true

  beluga_log "Creating PF Site"
  create_site
}

create_kibana_site() {
  export SITE_ID=21
  export SITE_NAME="Kibana"
  export SITE_TARGET="kibana.elastic-stack-logging:5601"
  export SITE_SECURE=false

  beluga_log "Creating Kibana Site"
  create_site
}

create_grafana_site() {
  export SITE_ID=22
  export SITE_NAME="Grafana"
  export SITE_TARGET="grafana.prometheus:3000"
  export SITE_SECURE=false

  beluga_log "Creating Grafana Site"
  create_site
}

create_prometheus_site() {
  export SITE_ID=23
  export SITE_NAME="Prometheus"
  export SITE_TARGET="prometheus.prometheus:9090"
  export SITE_SECURE=false

  beluga_log "Creating Prometheus Site"
  create_site
}

create_argocd_site() {
  export SITE_ID=24
  export SITE_NAME="Argo CD"
  export SITE_TARGET="argocd-server.argocd:443"
  export SITE_SECURE=true

  beluga_log "Creating Argo CD Site"
  create_site
}


create_site() {
  local site_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/site-payload.json)
  local resource=sites

  create_entity "${site_payload}" "${resource}"
  unset SITE_ID SITE_NAME SITE_TARGET SITE_SECURE
}

create_pa_application() {
  export APP_ID=10
  export APP_NAME="PingAccess App"
  export APP_DESCRIPTION="PingAccess Web Application"
  export VIRTUAL_HOST_ID=10
  export SITE_ID=10

  beluga_log "Creating PA Application"
  create_application
}

create_pf_application() {
  export APP_ID=20
  export APP_NAME="PingFederate App"
  export APP_DESCRIPTION="PingFederate Web Application"
  export VIRTUAL_HOST_ID=20
  export SITE_ID=20

  # PDO-2235 - To circumvent a double-auth AdminSSO
  # event for a MyPing user trying to access the PF Admin UI,
  # disable the WebSession for this app in PA WAS.
  beluga_log "Creating PF Application"
  if is_myping_deployment; then
    beluga_log "Disabling the WebSession for the PF Admin Application since this is a MyPing deployment"

    export SESSION_ID=0
    app_payload=$(envsubst < ${TEMPLATES_DIR_PATH}/application-payload.json)
    resource=applications

    create_entity "${app_payload}" "${resource}"
    unset APP_ID APP_NAME APP_DESCRIPTION VIRTUAL_HOST_ID SITE_ID SESSION_ID
  else
    create_application
  fi
}

create_kibana_application() {
  export APP_ID=21
  export APP_NAME="Kibana App"
  export APP_DESCRIPTION="Kibana Web Application"
  export VIRTUAL_HOST_ID=21
  export SITE_ID=21

  beluga_log "Creating Kibana Application"
  create_application
}

create_grafana_application() {
  export APP_ID=22
  export APP_NAME="Grafana App"
  export APP_DESCRIPTION="Grafana Web Application"
  export VIRTUAL_HOST_ID=22
  export SITE_ID=22

  beluga_log "Creating Grafana Application"
  create_application
}

create_prometheus_application() {
  export APP_ID=23
  export APP_NAME="Prometheus App"
  export APP_DESCRIPTION="Prometheus Web Application"
  export VIRTUAL_HOST_ID=23
  export SITE_ID=23

  beluga_log "Creating Prometheus Application"
  create_application
}

create_argocd_application() {
  export APP_ID=24
  export APP_NAME="Argo CD App"
  export APP_DESCRIPTION="Argo CD Web Application"
  export VIRTUAL_HOST_ID=24
  export SITE_ID=24

  beluga_log "Creating Argo CD Application"
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

  beluga_log "make_api_request response..."
  make_api_request -s -X POST -d "${payload}" "${ENDPOINT}"/"${resource}"
  return ${?}
}

update_entity() {
  local payload="${1}"
  local resource="${2}"
  local id="${3}"

  local context_path=""
  if test -z "${id}";then
    context_path="${ENDPOINT}"/"${resource}"
  else
    context_path="${ENDPOINT}"/"${resource}"/"${id}"
  fi

  beluga_log "make_api_request response..."
  make_api_request -s -X PUT -d "${payload}" "${context_path}"
  return ${?}
}

get_entity() {
  local resource="${1}"
  local id="${2}"

  make_api_request "${ENDPOINT}"/"${resource}"/"${id}"
  return ${?}
}

is_production_environment() {
  test "${ENVIRONMENT_TYPE}"
}

# PDO-1432 - Always update the reserved
# endpoint from /pa to /pa-was so that
# WAS archives don't reset this value
# and break the WAS liveness probe.
update_application_reserved_endpoint

if is_myping_deployment; then
  if is_previously_configured; then
    exit 0
  fi
  export P14C_CLIENT_ID="${CLIENT_ID}"
  export P14C_CLIENT_SECRET="${CLIENT_SECRET}"
else
  if is_previously_configured; then
    if p14c_credentials_changed; then
      update_web_session
    fi
    exit 0
  fi
fi

create_web_session
create_pa_virtual_host
create_pf_virtual_host
create_kibana_virtual_host
create_grafana_virtual_host
create_prometheus_virtual_host
create_argocd_virtual_host
create_pa_site
create_pf_site
create_kibana_site
create_grafana_site
create_prometheus_site
create_argocd_site
create_pa_application
create_pf_application
create_kibana_application
create_grafana_application
create_prometheus_application
create_argocd_application

beluga_log "Configuration complete"
