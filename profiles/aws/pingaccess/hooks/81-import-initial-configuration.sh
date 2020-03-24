#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

set -x

# Accept EULA
make_initial_api_request -X PUT -d '{ "email": null,
    "slaAccepted": true,
    "firstLogin": false,
    "showTutorial": false,
    "username": "Administrator"
}' https://localhost:9000/pa-admin-api/v3/users/1 > /dev/null

# Change default password
make_initial_api_request -X PUT -d '{
  "currentPassword": "'"${DEFAULT_PA_ADMIN_USER_PASSWORD}"'",
  "newPassword": "'"${PA_ADMIN_USER_PASSWORD}"'"
}' https://localhost:9000/pa-admin-api/v3/users/1/password > /dev/null

# Generate new keypair for cluster
OUT=$( make_api_request -X POST -d "{
          \"keySize\": 2048,
          \"subjectAlternativeNames\":[],
          \"keyAlgorithm\":\"RSA\",
          \"alias\":\"pingaccess-console\",
          \"organization\":\"Ping Identity\",
          \"validDays\":365,
          \"commonName\":\"${K8S_SERVICE_NAME_PINGACCESS_ADMIN}\",
          \"country\":\"US\",
          \"signatureAlgorithm\":\"SHA256withRSA\"
        }" https://localhost:9000/pa-admin-api/v3/keyPairs/generate )

PINGACESS_KEY_PAIR_ID=$( jq -n "$OUT" | jq '.id' )

# Retrieving CONFIG QUERY id
OUT=$( make_api_request https://localhost:9000/pa-admin-api/v3/httpsListeners )
CONFIG_QUERY_LISTENER_KEYPAIR_ID=$( jq -n "$OUT" | jq '.items[] | select(.name=="CONFIG QUERY") | .keyPairId' )
echo "CONFIG_QUERY_LISTENER_KEYPAIR_ID:${CONFIG_QUERY_LISTENER_KEYPAIR_ID}"

# Update CONFIG QUERY with cluster keypair
make_api_request -X PUT -d "{
    \"name\": \"CONFIG QUERY\",
    \"useServerCipherSuiteOrder\": false,
    \"keyPairId\": ${PINGACESS_KEY_PAIR_ID}
}" https://localhost:9000/pa-admin-api/v3/httpsListeners/${CONFIG_QUERY_LISTENER_KEYPAIR_ID}

# Update admin config host
make_api_request -X PUT -d "{
    \"hostPort\":\"${K8S_SERVICE_NAME_PINGACCESS_ADMIN}:9090\",
    \"httpProxyId\": 0,
    \"httpsProxyId\": 0
}" https://localhost:9000/pa-admin-api/v3/adminConfig