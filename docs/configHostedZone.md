# Configure customer hosted zone to allow ACME

In Ping Cloud, a Kubernetes application named cert-manager runs within the EKS cluster for a customer environment. The cert-manager application is an Automatic Certificate Management Environment (ACME) client that can automatically obtain certificates from the Let’s Encrypt production ACME server. The cert-manager application automatically takes care of renewing certificates before they expire. All popular browsers support ACME certificates, so this provides a hands-off and fully-automated approach to certificate management. For these reasons, we recommend using ACME certificates from Let’s Encrypt instead of custom certificates.

Let's Encrypt also supports the use of wildcard certificates. The Let’s encrypt production server has a rate limit of 50 certificates per DNS zone per week, unless you're using a wildcard certificate for a group of sites. In this case, it's much less likely to run into a limitation. Wildcard certificates also allow us to add more sites in the future without any further configuration.

By default, Ping Cloud Private Tenant provisions ACME certificates obtained from the Let’s Encrypt ACME server using wildcard certificates. Each customer environment automatically gets a single wildcard certificate that protects all of the sites for that environment. These sites include all the admin endpoints (such as, PingFederate Admin, PingDirectory LDAPS) and runtime endpoints (such as, PingFederate authorization).

When you replace the default domain used for our product endpoints, however, you need to also get a certificate for that domain. 

> The DNS propagation can take a long time, between 15 minutes to (in some cases) a couple of hours.


## Prerequisites

* The domain name must be registered with a valid DNS registrar.
* A hosted zone must be created for the domain on Route53 in the customer hub AWS account through an SRE request with Versent. 
* The NS (nameserver) DNS record type of this hosted zone must be configured using the name servers of the replacement domain. 
* The AWS name servers must be configured on the replacement domain through its registrar’s website.


## Replace the default domain

After the infrastructure is configured (the prerequisites), you can change domain names in the Ingress resource objects.

* Change the FQDN for the endpoint. Edit the `cluster-state-repo/k8s-configs/ping-cloud/kustomization.yaml` file as follows (PingFederate runtime is used for this example):

  ```yaml
  - target:
      group: extensions
      version: v1beta1
      kind: Ingress
      name: pingfederate-ingress
    patch: |
    - op: replace
      path: /spec/tls/0/hosts/0
      value:  <new-domain>
    - op: replace
      path: /spec/rules/0/host
      value:  <new-domain>
  ```

  Where \<new-domain> is the FQDN of the new domain.

## Get a new ACME certificate

The cert-manager application installs a few Custom Resource Definitions (CRDs) onto the Kubernetes server. Certificate and ClusterIssuer are the two CRDs that you'll need to configure to automatically obtain an ACME certificate for the new domain. 

There are two ways to do this:

* Get a certificate for each endpoint.
* Use a single wildcard certificate for all endpoints in the new domain.

### Get an ACME certificate for each endpoint

1. Configure the ClusterIssuer resource to issue certificates for the new DNS zone by adding the following to the `cluster-state-repo/k8s-configs/cluster-tools/kustomization.yaml` file (PingFederate runtime is used in this example):

   ```yaml
    apiVersion: certmanager.k8s.io/v1alpha1
   kind: ClusterIssuer
   metadata:
    name: letsencrypt-prod
   spec:
    acme:
      email: dev@dev-oyster.us1.ping-preview.cloud
      solvers:
      - dns01:
          route53:
            region: us-east-2
        selector:
          dnsZones:
          - stage-orca.us1.ping-lab.cloud
          - <new-domain>
   ```

   Where \<new-domain> is the FQDN of the new domain.

2. Create the file `cluster-state-repo/k8s-configs/ping-cloud/certificate-\<zone-name>.yaml`.

3. Create a new Certificate resource for the new DNS zone by adding the following to the `cluster-state-repo/k8s-configs/ping-cloud/certificate-\<new-domain>.yaml` file you created:

   ```yaml
   apiVersion: certmanager.k8s.io/v1alpha1
   kind: Certificate
   metadata:
     name: acme-tls-cert-<new-domain>-auth
     namespace: ping-cloud
   spec:
     secretName: acme-tls-cert-<new-domain>-auth
     issuerRef:
       name: letsencrypt-prod
       kind: ClusterIssuer
     dnsNames:
     - '<new-domain>'
     commonName: <new-domain>
   ```

   Where \<new-domain> is the FQDN of the new domain.

4. Include the `cluster-state-repo/k8s-configs/ping-cloud/certificate-\<new-domain>.yaml` file as a resource in the `cluster-state-repo/k8s-configs/ping-cloud/kustomization.yaml` file. For example:

   ```yaml
   kind: Kustomization
   apiVersion: kustomize.config.k8s.io/v1beta1

   namespace: ping-cloud

   resources:
   # All ping resources will live in the ping-cloud namespace
   - https://github.com/pingidentity/ping-cloud-base/k8s-configs/ping-cloud/prod/small?ref=v1.1-release-branch
   - <new-domain>.yaml
   ```

   When this certificate is issued, the cert-manager application will drop the certificate and its key into the `secretName` value you set for the Certificate resource in the prior step.

   > The DNS propagation can take a long time, between 15 minutes to (in some cases) a couple of hours.

5. Update the TLS secret name in the Ingress resource object to the secret you set for the Certificate resource in `cluster-state-repo/k8s-configs/ping-cloud/kustomization.yaml` (PingFederate runtime is used in this example): 

   > You'd patched this Ingress resource object earlier to add the new DNS name.

```yaml
- target:
    group: extensions
    version: v1beta1
    kind: Ingress
    name: pingfederate-ingress
  patch: |
  - op: replace
    path: /spec/tls/0/hosts/0
    value: <new-domain>
  - op: replace
    path: /spec/rules/0/host
    value: <new-domain>
  - op: add
    path: /spec/tls/secretName
    value: acme-tls-cert-<new-domain>-auth
```

### Use a single wildcard certificate for all endpoints

1. Configure the ClusterIssuer resource to issue certificates for the new DNS zone by adding the following to the `cluster-state-repo/k8s-configs/cluster-tools/kustomization.yaml` file:

   ```yaml
    apiVersion: certmanager.k8s.io/v1alpha1
   kind: ClusterIssuer
   metadata:
    name: letsencrypt-prod
   spec:
    acme:
      email: dev@dev-oyster.us1.ping-preview.cloud
      solvers:
      - dns01:
          route53:
            region: us-east-2
        selector:
          dnsZones:
          - stage-orca.us1.ping-lab.cloud
          - <new-domain>
   ```

   Where \<new-domain> is the FQDN of the new domain.

2. Create the file `cluster-state-repo/k8s-configs/ping-cloud/certificate-\<zone-name>.yaml`.

3. Create a new Certificate resource for the new DNS zone by adding the following to the `cluster-state-repo/k8s-configs/ping-cloud/certificate-\<new-domain>.yaml` file you created:

   > Note the "*." prefix for the `dnsNames` value. This indicates the use of wildcard certificates.

   ```yaml
   apiVersion: certmanager.k8s.io/v1alpha1
   kind: Certificate
   metadata:
     name: acme-tls-cert-<new-domain>-auth
     namespace: ping-cloud
   spec:
     secretName: acme-tls-cert-<new-domain>-auth
     issuerRef:
       name: letsencrypt-prod
       kind: ClusterIssuer
     dnsNames:
     - '*.<new-domain>'
     commonName: <new-domain>
   ```

   This will result in a wildcard certificate being issued for the new domain. This certificate can be used for any endpoint in the domain.

4. In the `cluster-state-repo/k8s-configs/cluster-tools/kustomization.yaml` file, update the default certificate used for the `nginx-ingress` controllers to use this wildcard certificate. For example: 

   ```yaml
   - target:
       group: apps
       version: v1
       kind: Deployment
       name: nginx-ingress-controller
       namespace: ingress-nginx-private
     patch: |-
     - op: add
       path: /spec/template/spec/containers/0/args/-
       value:
         --default-ssl-certificate=ping-cloud/acme-tls-cert-<new-domain>

   - target:
      group: apps
      version: v1
      kind: Deployment
      name: nginx-ingress-controller
      namespace: ingress-nginx-public
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value:
          --default-ssl-certificate=ping-cloud/acme-tls-cert-<new-domain>
   ```

> No changes to the `secretName` values in the Ingress resource objects are necessary when this method is used. 


