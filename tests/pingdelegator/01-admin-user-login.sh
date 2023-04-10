#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

ADD_USER_LDIF_FILE="${PROJECT_DIR}"/tests/pingdelegator/templates/add-users.ldif
DELETE_USER_LDIF_FILE="${PROJECT_DIR}"/tests/pingdelegator/templates/delete-users.ldif

SERVER="pingdirectory-0"
CONTAINER="pingdirectory"
USER_BASE_DN="dc=example,dc=com"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  TEST_CONFIG_FILE="/tmp/01-admin-user-login-test.config"
  touch ${TEST_CONFIG_FILE}

  TEST_PF_HTML_FORM=$(mktemp -t "pf-admin-login-form-XXXXXXXXXX")

  # Get the total number of PD servers
  NUM_REPLICAS=$(kubectl get statefulset "${CONTAINER}" -o jsonpath='{.spec.replicas}' -n "${PING_CLOUD_NAMESPACE}")
  NUM_REPLICAS=$((NUM_REPLICAS - 1))

  add_users
  create_delegated_rights_for_admin_user
}

oneTimeTearDown() {
  # Need this to suppress tearDown on script EXIT
  [[ "${_shunit_name_}" = 'EXIT' ]] && return 0

  delete_users
  delete_delegated_rights_for_admin_user

  # Remove test file from test environment and cluster
  rm ${TEST_CONFIG_FILE}
  rm ${TEST_PF_HTML_FORM}

  applyToAllServers "CLEANUP"
  
  unset TEST_CONFIG_FILE
  unset TEST_PF_HTML_FORM
}

# Helper Methods

add_users() {
  kubectl cp ${ADD_USER_LDIF_FILE} "${SERVER}:${TEST_CONFIG_FILE}" -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}"
  kubectl exec "${SERVER}" -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}" -- \
    sh -c "ldapmodify --defaultAdd --ldifFile ${TEST_CONFIG_FILE} > /dev/null"
}

delete_users() {
  kubectl cp ${DELETE_USER_LDIF_FILE} "${SERVER}:${TEST_CONFIG_FILE}" -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}"
  kubectl exec "${SERVER}" -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}" -- \
    sh -c "ldapdelete --filename ${TEST_CONFIG_FILE} > /dev/null"
}

loginIntoPF() {

  local da_fqdn="pingdelegator${ENVIRONMENT}.${TENANT_DOMAIN}"

  local pf_login_url="${PINGFEDERATE_AUTH_ENDPOINT}/as/authorization.oauth2"
  local client_id="client_id=dadmin"
  local da_redirect_uri="redirect_uri=https%3A%2F%2F${da_fqdn}%2Fdelegator%23%2Fcallback"
  local response_type="response_type=token%20id_token"
  local scope="scope=openid%20urn%3Apingidentity%3Adirectory-delegated-admin"
  local nonce="nonce=0f1582af043a466daef0e316f1e1f543"

  local pf_form_url="${pf_login_url}?${client_id}&${da_redirect_uri}&${response_type}&${scope}&${nonce}"

  local pf_cookie=$(curl -ksc - "${pf_form_url}" -o ${TEST_PF_HTML_FORM} | awk '/PF/{print $NF}')
  
  local pf_action_url=$(awk '/\/resume\/as\/authorization.ping/' ${TEST_PF_HTML_FORM} | awk -F '"' '$0=$4')

  # Use PF cookie and attempt to log user admin in by filling out form
  ACCESS_TOKEN_CALLBACK=$(curl -ksL "${PINGFEDERATE_AUTH_ENDPOINT}${pf_action_url}" \
  -H "content-type: application/x-www-form-urlencoded" \
  -H "cookie: PF=${pf_cookie}" \
  -d pf.username=administrator \
  -d pf.pass=2FederateM0re \
  -d pf.ok=clicked \
  -d pf.adapterId=daidphtml \
  -w "%{http_code}" \
  -o /dev/null \
  -w %{url_effective})
}

create_delegated_rights_for_admin_user() {
  cat > ${TEST_CONFIG_FILE} <<-EOF
    dsconfig create-delegated-admin-rights \
      --rights-name dadmin \
      --set "admin-user-dn:uid=administrator,ou=people,${USER_BASE_DN}" \
      --set enabled:true

    dsconfig create-delegated-admin-resource-rights \
      --rights-name dadmin \
      --rest-resource-type users \
      --set admin-permission:create \
      --set admin-permission:read \
      --set admin-permission:update \
      --set admin-permission:delete \
      --set admin-permission:manage-group-membership \
      --set admin-scope:all-resources-in-base \
      --set enabled:true
EOF
  applyToAllServers "DS_CONFIG"
}

delete_delegated_rights_for_admin_user() {
  cat > ${TEST_CONFIG_FILE} <<-EOF
    dsconfig delete-delegated-admin-resource-rights \
      --rights-name dadmin \
      --rest-resource-type users

    dsconfig delete-delegated-admin-rights \
      --rights-name dadmin
EOF
  applyToAllServers "DS_CONFIG"
}

applyToAllServers() {
  local replica_index=${NUM_REPLICAS}

  while test ${replica_index} -gt -1; do
    SERVER="${CONTAINER}-${replica_index}"

    case "${1}" in
      DS_CONFIG)
        kubectl cp ${TEST_CONFIG_FILE} "${SERVER}":"${TEST_CONFIG_FILE}"  -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}"
        kubectl exec "${SERVER}" -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}" -- \
          sh -c "dsconfig --no-prompt --batch-file ${TEST_CONFIG_FILE} > /dev/null"
        ;;
      CLEANUP)
        kubectl exec "${SERVER}" -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}" -- \
          sh -c "rm ${TEST_CONFIG_FILE} > /dev/null"
        ;;
    esac

    replica_index=$((replica_index - 1))
  done
}

# Since DA is a Single Page App written in react the following test will: 
# 1) Test the PingFederate login form by logging in a DA administrator.
# 2) Upon login, retrieve an access token. With that token, the test makes a request
# to the exposed Delegated Admin API that is provided by PingDirectory.
testDA_API() {

  ACCESS_TOKEN_CALLBACK=

  # Login into PF and get access token
  loginIntoPF
  assertEquals 0 $?

  echo "${ACCESS_TOKEN_CALLBACK}" | grep access_token > /dev/null
  assertEquals 0 $?  

  # Use access token to perform user lookup from PD

  local access_token=$(echo "${ACCESS_TOKEN_CALLBACK}" | awk -v FS="(access_token=|&)" '{print $2}')

  local pd_response=$(curl -ks "${PINGDIRECTORY_API}/dadmin/v2/users?filter=user.0" \
  -H "authorization: Bearer ${access_token}")
  assertEquals 0 $?

  local found_uid=$(echo "${pd_response}" | jq -r '.data[].attributes.uid[0]')

  assertEquals "user.0" "${found_uid}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
