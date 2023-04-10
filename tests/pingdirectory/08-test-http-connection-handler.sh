#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

ADD_USER_LDIF_FILE="${PROJECT_DIR}"/tests/pingdirectory/templates/add-user.ldif
DELETE_USER_LDIF_FILE="${PROJECT_DIR}"/tests/pingdirectory/templates/delete-user.ldif

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  PRODUCT_NAME="pingdirectory"
  TEST_LDIF_FILE=/tmp/08-test-http-connection-handler.ldif
  touch ${TEST_LDIF_FILE}

  # Get the total number of PD servers
  NUM_REPLICAS=$(kubectl get statefulset "${PRODUCT_NAME}" -o jsonpath='{.spec.replicas}' -n "${PING_CLOUD_NAMESPACE}")
  NUM_REPLICAS=$((NUM_REPLICAS - 1))

  # Create SCIM resource and add users to PD
  # Server will need to be configured beforehand, in order to test API and SCIM endpoints
  create_scim_resource
  add_users
}

oneTimeTearDown() {
  # Need this to suppress tearDown on script EXIT
  [[ "${_shunit_name_}" = 'EXIT' ]] && return 0

  remove_scim_resource
  delete_users

  # Remove test file from test environment and cluster
  rm ${TEST_LDIF_FILE}
  applyToAllServers "CLEANUP"
  unset TEST_LDIF_FILE
}

# Helper Methods

remove_scim_resource() {
  cat > ${TEST_LDIF_FILE} <<-EOF
    dsconfig delete-scim-attribute-mapping \
      --type-name People \
      --mapping-name description

    dsconfig delete-scim-attribute-mapping \
        --type-name People \
        --mapping-name name

    dsconfig delete-scim-resource-type \
        --type-name People

    dsconfig delete-scim-attribute \
        --schema-name urn:pingidentity:schemas:Person:1.0 \
        --attribute-name description

    dsconfig delete-scim-attribute \
        --schema-name urn:pingidentity:schemas:Person:1.0 \
        --attribute-name name

    dsconfig delete-scim-schema \
        --schema-name urn:pingidentity:schemas:Person:1.0

    dsconfig set-http-servlet-extension-prop \
        --extension-name SCIM2 \
        --remove "access-token-validator:SCIM2 Mock Validator"

    dsconfig delete-access-token-validator \
        --validator-name "SCIM2 Mock Validator"
EOF
  applyToAllServers "RUN_LDIF"
}

create_scim_resource() {
  cat > ${TEST_LDIF_FILE} <<-EOF
    dsconfig create-access-token-validator \
    --validator-name "SCIM2 Mock Validator"  \
    --type mock  \
    --set enabled:true

    dsconfig set-http-servlet-extension-prop \
        --extension-name SCIM2  \
        --set "access-token-validator:SCIM2 Mock Validator"

    dsconfig create-scim-schema \
      --schema-name urn:pingidentity:schemas:Person:1.0 \
      --set display-name:Person

    dsconfig create-scim-attribute \
      --schema-name urn:pingidentity:schemas:Person:1.0 \
      --attribute-name name \
      --set required:true

    dsconfig create-scim-attribute \
      --schema-name urn:pingidentity:schemas:Person:1.0 \
      --attribute-name description

    dsconfig create-scim-resource-type \
      --type-name People \
      --type ldap-mapping \
      --set enabled:true \
      --set endpoint:People \
      --set structural-ldap-objectclass:person \
      --set include-base-dn:ou=People,dc=example,dc=com \
      --set lookthrough-limit:500 \
      --set core-schema:urn:pingidentity:schemas:Person:1.0

    dsconfig create-scim-attribute-mapping \
      --type-name People \
      --mapping-name name \
      --set scim-resource-type-attribute:name \
      --set ldap-attribute:cn \
      --set searchable:true

    dsconfig create-scim-attribute-mapping \
      --type-name People \
      --mapping-name description \
      --set scim-resource-type-attribute:description \
      --set ldap-attribute:description
EOF
  applyToAllServers "RUN_LDIF"
}

add_users() {
  kubectl cp ${ADD_USER_LDIF_FILE} pingdirectory-0:"${TEST_LDIF_FILE}" -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}"
  kubectl exec pingdirectory-0 -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}" -- \
    sh -c "ldapmodify --defaultAdd --ldifFile ${TEST_LDIF_FILE} > /dev/null"
}

delete_users() {
  kubectl cp ${DELETE_USER_LDIF_FILE} pingdirectory-0:"${TEST_LDIF_FILE}" -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}"
  kubectl exec pingdirectory-0 -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}" -- \
    sh -c "ldapdelete --filename ${TEST_LDIF_FILE} > /dev/null"
}

applyToAllServers() {
  local replica_index=${NUM_REPLICAS}

  while test ${replica_index} -gt -1; do
    SERVER="${PRODUCT_NAME}-${replica_index}"
    CONTAINER="${PRODUCT_NAME}"

    case "${1}" in
      RUN_LDIF)
        kubectl cp ${TEST_LDIF_FILE} "${SERVER}":"${TEST_LDIF_FILE}"  -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}"
        kubectl exec "${SERVER}" -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}" -- \
          sh -c "dsconfig --no-prompt --batch-file ${TEST_LDIF_FILE} > /dev/null"
        ;;
      CLEANUP)
        kubectl exec "${SERVER}" -c "${CONTAINER}" -n "${PING_CLOUD_NAMESPACE}" -- \
          sh -c "rm ${TEST_LDIF_FILE} > /dev/null"
        ;;
    esac

    replica_index=$((replica_index - 1))
  done
}

# Test Methods
testApi() {
  local expected_user_cn="john.0"

  user_profile_response=$(curl -k -u "user.0:password" -X GET "${PINGDIRECTORY_API}/directory/v1/me")
  actual_user_cn=$(jq -n "${user_profile_response}" | jq -r '.cn | .[]')

  assertEquals ${expected_user_cn} ${actual_user_cn}
}

testScim() {
  local expected_scim_resource_id="People"

  scim_resource_response=$( curl -k -X GET "${PINGDIRECTORY_API}/scim/v2/ResourceTypes" \
    -H 'Authorization: Bearer {"active":true}' )
  actual_scim_resource_id=$(jq -n "${scim_resource_response}"  | jq -r '.Resources[] | .id' )

  assertEquals ${expected_scim_resource_id} ${actual_scim_resource_id}
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}