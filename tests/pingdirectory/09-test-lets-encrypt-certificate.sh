#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"


if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

POD_NAME="pingdirectory-0"
CONTAINER_NAME="pingdirectory"

oneTimeTearDown() {
  # Need this to suppress tearDown on script EXIT
  [[ "${_shunit_name_}" = 'EXIT' ]] && return 0

  # Cleanup temporary files
  log "Cleaning up temporary certificate files..."
  rm -f /tmp/server-cert-keystore.crt \
        /tmp/server-cert-truststore.crt \
        /tmp/cluster-certificate.crt \
        /tmp/keystore.pem \
        /tmp/truststore.pem \
        /tmp/cluster.pem
}

testCertificateInKeystore() {

  log "Test: Verify Let's Encrypt Certificate in PingDirectory Keystore and TrustStore (without replacing)"

  log "Exporting Keystore certificate from PingDirectory pod..."
  kubectl exec -n $PING_CLOUD_NAMESPACE $POD_NAME -c $CONTAINER_NAME -- sh -c \
    'manage-certificates export-certificate \
      --keystore $SERVER_RUNTIME_DIR/config/keystore \
      --keystore-password-file $SERVER_RUNTIME_DIR/config/keystore.pin \
      --alias server-cert \
      --output-file /tmp/server-cert-keystore.crt \
      --output-format PEM'
  assertEquals "Failed to run 'manage-certificates export-certificate' for keystore" 0 $?

  kubectl cp -c $CONTAINER_NAME $PING_CLOUD_NAMESPACE/$POD_NAME:/tmp/server-cert-keystore.crt /tmp/server-cert-keystore.crt

  log "Fetching Let's Encrypt cert from Kubernetes secret..."
  cluster_certificate=$(kubectl get secret acme-tls-cert -n $PING_CLOUD_NAMESPACE -o jsonpath='{.data.tls\.crt}')
  assertEquals "Error retrieving cluster certificate" 0 $?
  echo -n "$cluster_certificate" | base64 --decode > /tmp/cluster-certificate.crt

  # Normalize certificates using openssl to avoid formatting mismatch
  log "Normalizing all certificates..."
  openssl x509 -in /tmp/cluster-certificate.crt -out /tmp/cluster.pem
  openssl x509 -in /tmp/server-cert-keystore.crt -out /tmp/keystore.pem

  # Compare cluster cert with keystore
  log "Comparing Cluster Cert with Keystore Cert..."
  cmp -s /tmp/cluster.pem /tmp/keystore.pem
  assertEquals "Cluster cert DOES NOT match Keystore cert" 0 $?
}

testCertificateInTruststore() {

  log "Exporting Truststore certificate from PingDirectory pod..."
  kubectl exec -n $PING_CLOUD_NAMESPACE $POD_NAME -c $CONTAINER_NAME -- sh -c \
    'manage-certificates export-certificate \
      --keystore $SERVER_RUNTIME_DIR/config/truststore \
      --keystore-password-file $SERVER_RUNTIME_DIR/config/truststore.pin \
      --alias server-cert \
      --output-file /tmp/server-cert-truststore.crt \
      --output-format PEM'
  assertEquals "Failed to run 'manage-certificates export-certificate' for truststore" 0 $?

  kubectl cp -c $CONTAINER_NAME $PING_CLOUD_NAMESPACE/$POD_NAME:/tmp/server-cert-truststore.crt /tmp/server-cert-truststore.crt

  log "Fetching Let's Encrypt cert from Kubernetes secret..."
  cluster_certificate=$(kubectl get secret acme-tls-cert -n $PING_CLOUD_NAMESPACE -o jsonpath='{.data.tls\.crt}')
  assertEquals "Error retrieving cluster certificate" 0 $?
  echo -n "$cluster_certificate" | base64 --decode > /tmp/cluster-certificate.crt

  # Normalize certificates using openssl to avoid formatting mismatch
  log "Normalizing all certificates..."
  openssl x509 -in /tmp/cluster-certificate.crt -out /tmp/cluster.pem
  openssl x509 -in /tmp/server-cert-truststore.crt -out /tmp/truststore.pem

  # Compare cluster cert with truststore
  log "Comparing Cluster Cert with Truststore Cert..."
  cmp -s /tmp/cluster.pem /tmp/truststore.pem
  assertEquals "Cluster cert DOES NOT match Truststore cert" 0 $?
}

shift $#

. ${SHUNIT_PATH}

