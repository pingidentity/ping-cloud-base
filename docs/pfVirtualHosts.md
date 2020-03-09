# Create customer defined virtual host for PingFederate

When you create a new virtual host, by default, the Let’s Encrypt Automatic Certificate Management Environment (ACME) server assigns a certificate to the virtual host. If you aren't also creating a new domain, you don't need to worry about certificates.

If you *are* creating a new domain, you'll also need to create a certificate for the domain. See the topic **Configure customer hosted zone to allow ACME** for information. 

1. Create the new virtual hosts in PingFederate:

   ```curl
   curl -u administrator:2FederateM0re -X PUT -k 'https://<pfHost>:<port>/pingfederate/app' -d "{virtualHostNames:["<vhost1>","<vhost2",...]}" --header 'x-xsrf-header: PingFederate'
   ```

   Where \<pfHost> identifies the PingFederate host location and \<vhost1>, \<vhost2> is the list of virtual host names to create.

2. Connect to the AWS management node for the CDE, and clone the cluster-state repo to a local directory.

   > See the Versent document [How to connect to CDE through Platform Hub Account - AWS CLI](https://versent-ping.atlassian.net/wiki/spaces/PPSRE/pages/169836573/How+to+connect+to+CDE+through+Platform+Hub+Account+-+AWS+CLI) for instructions in connecting to the AWS management node for the CDE.

3. You can add the new virtual host names by either:

   * Creating a new Ingress resource object for PingFederate.
   * Editing the existing Ingress resource object and replacing the default host name with the new virtual host name.

## Create a new Ingress resource object for PingFederate

1. To create the new Ingress resource object, copy the example below to a new *.yaml file in the `cluster-state-repo/k8s-configs/ping-cloud` directory. 

     ```yaml
     apiVersion: extensions/v1beta1
     kind: Ingress
     metadata:
      name: <new-vhost-name>-pingfederate-ingress
      namespace: ping-cloud
      annotations:
        nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
        kubernetes.io/ingress.class: nginx-public
     spec:
      tls:
      - hosts:
        - <new-vhost-name>.stage-orca.us1.ping-lab.cloud
      rules:
      - host: <new-vhost-name>.stage-orca.us1.ping-lab.cloud
        http:
          paths:
          - path: /
            backend:
              serviceName: pingfederate
              servicePort: 9031
     ```

2. Change \<`new-vhost-name`> to a virtual host name you've added to PingFederate.

3. Add the new *.yaml file to the "resources" section of the `kustomization.yaml` file in the same directory.

4. Push your changes in Git. Flux will propagate the change to the cluster. The change can take up to 10 minutes for the new host name to be resolved by the DNS servers.

     Entering `kubectl get ingress -A` will show the new hostname.

     When deployed to the cluster, the PingFederate runtime endpoint will be accessible at the default host (`https://pingfederate.stage-orca.us1.ping-lab.cloud`) and the new virtual host (`https://\<new-vhost-name>.stage-orca.us1.ping-lab.cloud`). 

     If you want to use only the new virtual host (the new Ingress resource object), you can then delete the default Ingress resource object (the `pingfederate` host). 

## Edit the existing host name

If you know that you don't want to use the default host name, you can replace the default host name with the new virtual host name in the `/spec/hosts` and `/spec/rules/host` sections of the Ingress resource object in `cluster-state-repo/k8s-configs/ping-cloud/kustomization.yaml`. 

* Edit `cluster-state-repo/k8s-configs/ping-cloud/kustomization.yaml` and replace the default host name for the PingFederate runtime (`pingfederate`) with a new virtual host name (\<`new-vhost-name`>). For example:

   ```yaml
   - target:
       group: extensions
       version: v1beta1
       kind: Ingress
       name: pingfederate-ingress
     patch: |
     - op: replace
       path: /spec/tls/0/hosts/0
       value:  <new-vhost-name>.stage-orca.us1.ping-lab.cloud
       - op: replace
         path: /spec/rules/0/host
         value: <new-vhost-name>.stage-orca.us1.ping-lab.cloud
   ```
