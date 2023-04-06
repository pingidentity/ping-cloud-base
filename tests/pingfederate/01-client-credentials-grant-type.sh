#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# FIXME Data needs preloading to CICD Bucket and OAuth client created
log "Test disabled pending new config setup"
exit 0

#
# UNTESTED template code to create OAuth client through PF API.
#
#client='{
#      "clientId": "OIDC-AS3",
#      "enabled": true,
#      "redirectUris": [],
#      "grantTypes": [
#        "RESOURCE_OWNER_CREDENTIALS",
#        "REFRESH_TOKEN"
#      ],
#      "name": "OIDC-AS",
#      "refreshRolling": "SERVER_DEFAULT",
#      "persistentGrantExpirationType": "SERVER_DEFAULT",
#      "persistentGrantExpirationTime": 0,
#      "persistentGrantExpirationTimeUnit": "DAYS",
#      "persistentGrantIdleTimeoutType": "SERVER_DEFAULT",
#      "persistentGrantIdleTimeout": 0,
#      "persistentGrantIdleTimeoutTimeUnit": "DAYS",
#      "bypassApprovalPage": false,
#      "restrictScopes": false,
#      "restrictedScopes": [],
#      "exclusiveScopes": [],
#      "restrictedResponseTypes": [],
#      "defaultAccessTokenManagerRef": {
#        "id": "jwt",
#        "location": "https://pingfederate-admin-68c57f7c54-fs5q4:9999/pf-admin-api/v1/oauth/accessTokenManagers/jwt"
#      },
#      "validateUsingAllEligibleAtms": false,
#      "oidcPolicy": {
#        "grantAccessSessionRevocationApi": false,
#        "pingAccessLogoutCapable": false,
#        "pairwiseIdentifierUserType": false
#      },
#      "clientAuth": {
#        "type": "NONE",
#        "enforceReplayPrevention": false
#      },
#      "deviceFlowSettingType": "SERVER_DEFAULT",
#      "requireProofKeyForCodeExchange": false,
#      "requireSignedRequests": false
#    }'
#
#
#curl  -v -k -u "Administrator:2FederateM0re" -H "X-XSRF-Header: PingFederate"  -H "Accept: application/json" -H "content-type: application/json" -d "'${client}'" https://pingfederate-admin-raypf.ping-demo.com:9999/pf-admin-api/v1/oauth/clients

URL="${PINGFEDERATE_AUTH_ENDPOINT}/as/token.oauth2?grant_type=client_credentials&scope="
log "Attempting to obtain access token from ${URL}"

curl --max-time 120 --silent -v -k -X POST -u 'PingDirectory:2FederateM0re' "${URL}"
exit ${?}
