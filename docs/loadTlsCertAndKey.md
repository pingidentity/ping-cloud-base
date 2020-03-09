# Load customer TLS Certificate and Key into PingCloud

When you're using custom certificates, instead of the Kubernetes cert-manager application owning the lifecycle of the certificate (specifically the secret associated with it), it is up to the administrator to own the lifecycle of the secret that contains the customer’s certificate. 

The configuration depends on whether this certificate is site-specific or a wildcard certificate for their entire domain.

1. In the `cluster-state-repo/k8s-configs/ping-cloud` directory, create the YAML file `tls-cert-\<new-domain>.yaml` to use for the secret object. 

2. Use the following example, and add the Base64-encoded strings for the certificate and its key into the tls.crt and tls.key properties:

   ```yaml
   apiVersion: v1
   data:
    tls.crt: <custom-certificate-pem-base64-encoded>
    tls.key: <custom-key-pem-base64-encoded>
    kind: Secret
    metadata:
      name: acme-tls-cert-<new-domain>
      namespace: ping-cloud
    type: kubernetes.io/tls
   ```

   > To create the Base64-encoded strings (Linux), enter:

   ```bash
   cat certificate.pem | base64 | tr -d '\r?\n'
   ```

3. Include the `cluster-state-repo/k8s-configs/ping-cloud/tls-cert-\<new-domain>.yaml` file as a resource in the `cluster-state-repo/k8s-configs/ping-cloud/kustomization.yaml` file. For example:

   ```yaml
   kind: Kustomization
   apiVersion: kustomize.config.k8s.io/v1beta1

   namespace: ping-cloud

   resources:
   # All ping resources will live in the ping-cloud namespace
   - https://github.com/pingidentity/ping-cloud-base/k8s-configs/ping-cloud/prod/small?ref=v1.1-release-branch
   - <new-domain>.yaml
   - tls-cert-\<new-domain>.yaml
   ```

4. Do one of the following, depending on whether the certificate is site-specific or a domain-wide wildcard:

   * For site-specific certificates, repeat the prior steps for each site. 

   * For a domain-wide wildcard certificate:
  
    a. Create a single secret object for the entire domain (prior steps 1 and 2).

    b. Update the `--default-ssl-certificate` argument of the `nginx-ingress` controllers to point to the secret object. 
