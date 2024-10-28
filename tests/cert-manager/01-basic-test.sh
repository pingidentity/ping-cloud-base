#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
    # Get the letsencrypt staging root certificate
    curl --output-dir /usr/local/share/ca-certificates/ \
        https://letsencrypt.org/certs/staging/letsencrypt-stg-root-x1.pem \
        -o letsencrypt-stg-root-x1.crt
    # Add staging root CA to trust store so we can verify cert-manager is working
    update-ca-certificates
}

testCertCreatedAndReady() {
    message=$(kubectl get certificate acme-tls-cert -n ping-cloud -o jsonpath='{.status.conditions[*].message}')
    assertEquals "Certificate acme-tls-cert is not ready" "Certificate is up to date and has not expired" "${message}"
}

testCertSecretHasThreeItems() {
    secret_data_len=$(kubectl get secret acme-tls-cert -n ping-cloud -o jsonpath='{.data}' | jq -r 'keys | length')
    assertEquals "Secret acme-tls-cert does not have three items" "3" "${secret_data_len}"
}

# Tests a few things at once - cert-manager cert, External DNS for the DNS record, and NGINX controller
# May fail if any of the above are having issues
testNginxPublicMetadataEndpoint() {
  metadata_ingress_url=$(kubectl get ingress metadata-ingress -n ping-cloud -o jsonpath='{.spec.rules[*].host}')
  log "Got 'ingress-metadata' ingress URL: ${metadata_ingress_url}"
  nginx_metadata_resp_code=$(curl -v "https://${metadata_ingress_url}" -o /dev/null -w "%{http_code}")
  assertEquals "Metadata ingress response code was not 200" "200" "${nginx_metadata_resp_code}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}