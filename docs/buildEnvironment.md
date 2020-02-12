# Build the K8s environment


## Prerequisites

* You've installed [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (version v1.14 or greater).
* You've installed [kustomize](https://kustomize.io/) (version v3.2 or greater).
* You've installed envsubst (version 0.20 or greater). This tool substitutes shell format strings with environment variables. See [envsubst](https://command-not-found.com/envsubst) if your OS doesn't have this utility.
* A Ping Identity account. See ...
* DevOps registration. See ...
* These environment variables must be exported:
  - `PING_IDENTITY_DEVOPS_USER`
  - `PING_IDENTITY_DEVOPS_KEY`
  - `BACKUP_URL`

    `BACKUP_URL` must reference an AWS S3 bucket. In clustered mode (the default), PingFederate requires an S3 bucket for high availability and fault tolerance. 

  - `TENANT_DOMAIN`

    `TENANT_DOMAIN` must be an AWS registered domain and hosted zone on Route53 in the same AWS IAM role (such as, arn:aws:iam::555555555555:role/ROLE) as your EKS cluster. For example, if `TENANT_DOMAIN` is set to `k8s-icecream.ping-devops.com`, then `ping-devops.com` must be a valid DNS domain registered by some registrar (such as, AWS Route53). There must also be a hosted zone created for it on AWS Route53.
    Refer to the AWS documentation to set these up.


## Build the environment

1. Use kustomize to build the K8s environment. Enter:

   ```bash
   kustomize build https://github.com/pingidentity/ping-cloud-base?ref=master |
     envsubst '
       ${PING_IDENTITY_DEVOPS_USER}
       ${PING_IDENTITY_DEVOPS_KEY}
       ${BACKUP_URL}
       ${TENANT_DOMAIN}' |
     kubectl apply -f -
   ```

2. To monitor the environment, enter:

   ```bash
   kubectl get pods -n ping-cloud
   ```

3. When all pods are ready, you can access:

   * Pingdirectory console: `https://pingdataconsole.k8s-icecream.ping-devops.com/console`

   * Pingfederate console: `https://pingfederate-admin.k8s-icecream.ping-devops.com/pingfederate/app`

   * Pingfederate API: `https://pingfederate-admin.k8s-icecream.ping-devops.com/pf-admin-api/api-docs`

   * Pingfederate runtime endpoint: `https://pingfederate.k8s-icecream.ping-devops.com`

   * Pingfederate oauth playground: `https://pingfederate.k8s-icecream.ping-devops.com/OAuthPlayground`

   * Pingaccess console: `https://pingaccess-admin.k8s-icecream.ping-devops.com`

   * Pingaccess API: `https://pingaccess-admin.k8s-icecream.ping-devops.com/pa-admin-api/v3/api-docs/`

   * Pingaccess runtime endpoint: `https://pingaccess.k8s-icecream.ping-devops.com`

   * Kibana console: `https://logs.k8s-icecream.ping-devops.com`


