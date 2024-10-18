#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}/common.sh" "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

## Common Methods

get_nlb_service() {
  type=$1
  # Get ingress URL to avoid hardcoding it
  nginx_service_url=$(kubectl get service ingress-nginx -n "ingress-nginx-${type}" -o jsonpath='{.status.loadBalancer.ingress[*].hostname}')
  assertNotNull "NGINX service load balancer URL was unexpectedly null!" "${nginx_service_url}"
  log "Got 'ingress-nginx' ${type} service URL: ${nginx_service_url}"

  # Make a request against the URL, check the response code is 200, ignore cert issue since going straight to NLB
  nginx_service_resp_code=$(curl -k -v "https://${nginx_service_url}" -o /dev/null -w "%{http_code}")

  # When going directly to the service, we should get a 404 from NGINX. This tests NGINX directly while removing
  # dependencies on underlying applications which might have issues (metadata service, pa-was, etc...)
  assertEquals "NGINX service ${type} response code was not 404" "404" "${nginx_service_resp_code}"
}

check_configmap_key_exists() {
  namespace=$1
  configmap=$2
  key=$3
  log "Checking for key '${key}' in configmap '${configmap}' in namespace '${namespace}'"
  kubectl get cm "${configmap}" -n "${namespace}" -o yaml | yq -e ".data.${key}" > /dev/null
  assertEquals "Configmap '${configmap}' in namespace '${namespace}' missing key '${key}'" 0 $?
}

## Tests

testNginxIngressClass(){
  log "Checking number of ingress classes"
  # Use xargs for whitespace trimming...
  num_ingress_classes=$(kubectl get ingressclass -A -o json | jq -r '.items[].metadata.name' | wc -l | xargs)
  expected_num_ingress_classes=2
  assertEquals "Number of ingress classes should have been two - public and private" "${num_ingress_classes}" "${expected_num_ingress_classes}"
}

testNginxPrivateNlbService404(){
  get_nlb_service "private"
}

testNginxPublicNlbService404(){
  get_nlb_service "public"
}

# Tests a few things at once - External DNS for the DNS record, and NGINX controller
# for routing to the metadata service. May fail if metadata is having issues, but it's the simplest service to point to.
# Does NOT test certificate - this is done in the cert-manager tests
testNginxPublicMetadataEndpoint() {
  metadata_ingress_url=$(kubectl get ingress metadata-ingress -n ping-cloud -o jsonpath='{.spec.rules[*].host}')
  log "Got 'ingress-metadata' ${type} ingress URL: ${metadata_ingress_url}"
  nginx_metadata_resp_code=$(curl -k -v "https://${metadata_ingress_url}" -o /dev/null -w "%{http_code}")
  assertEquals "Metadata ingress response code was not 200" "200" "${nginx_metadata_resp_code}"
}

testNginxSigSciModule() {
  command_to_run="grep sigsci_module /etc/nginx/nginx.conf"
  log "Checking for SigSci module loaded in config at /etc/nginx/nginx.conf"
  kubectl exec -ti -n ingress-nginx-public deployment/nginx-ingress-controller -c nginx-ingress-controller -- ${command_to_run}
  assertEquals "Module not found in NGINX public" 0 $?
}

testSigSciVersion() {
  # NOTE: Version must be updated each time we upgrade SigSci... at least for now
  sigsci_expected_version="4.57.0"
  command_to_run="/home/sigsci/sigsci-agent --version"
  log "Checking SigSci version in SigSci agent container against expected version: ${sigsci_expected_version}"
  sigsci_found_version=$(kubectl exec -ti -n ingress-nginx-public deployment/nginx-ingress-controller -c sigsci-agent -- ${command_to_run})
  # Remove carriage returns from output
  command_filtered=$(echo "${sigsci_found_version}" | sed -e 's/\r//g')
  assertEquals "Correct SigSci version not found" "${sigsci_expected_version}" "${command_filtered}"
}

testNginxPrivateConfigMap() {
  check_configmap_key_exists "ingress-nginx-private" "nginx-configuration" "location-snippet"
  check_configmap_key_exists "ingress-nginx-private" "nginx-configuration" "log-format-upstream"
}

testNginxPublicConfigMap() {
  check_configmap_key_exists "ingress-nginx-public" "nginx-configuration" "location-snippet"
  check_configmap_key_exists "ingress-nginx-public" "nginx-configuration" "log-format-upstream"
  check_configmap_key_exists "ingress-nginx-public" "nginx-configuration" "main-snippet"
  check_configmap_key_exists "ingress-nginx-public" "nginx-configuration" "max-worker-connections"
  check_configmap_key_exists "ingress-nginx-public" "nginx-configuration" "ssl-ciphers"
  check_configmap_key_exists "ingress-nginx-public" "nginx-configuration" "ssl-dh-param"
  check_configmap_key_exists "ingress-nginx-public" "nginx-configuration" "worker-processes"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}