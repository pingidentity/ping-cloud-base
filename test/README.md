# Summary

This directory allows anyone to set up a cookie-cutter Ping Software stack on
a Kubernete clusters for evaluation purposes. Currently only AWS EKS clusters
are supported.

# Testing

The following tools must be set up and configured correctly:

- kubectl
- kustomize
- envsubst

To set up the environment, the following environment variables must be exported
at the very minimum:

- PING_IDENTITY_DEVOPS_USER
- PING_IDENTITY_DEVOPS_KEY
- TENANT_DOMAIN

The DEVOPS user and key may be obtained from the Ping DevOps GTE team here:
```
https://docs.google.com/forms/d/e/1FAIpQLSdgEFvqQQNwlsxlT6SaraeDMBoKFjkJVCyMvGPVPKcrzT3yHA/viewform
```

The TENANT_DOMAIN must be an AWS registered domain and hosted zone on Route53 in
the same AWS IAM role (e.g. arn:aws:iam::574076504146:role/GTE) as your EKS
cluster. For example, if it is set to k8s-icecream.ping-devops.com, then
ping-devops.com must be a valid DNS domain registered by some registrar (e.g.
AWS Route53). There must also be a hosted zone created for it on AWS Route53.
Refer to the AWS online documentation on how to set these up.

To build the environment, simply run:

```
kustomize build https://gitlab.corp.pingidentity.com/ping-cloud-private-tenant/ping-cloud-base/test?ref=master | envsubst | kubectl apply -f -
```

Monitor it by running:
```
kubectl get pods -n ping-cloud
```

When all pods are ready, you should be able to access the following URLs:

```
Pingdirectory console:
https://k8s-icecream.ping-devops.com/console

Pingdirectory data:
https://k8s-icecream.ping-devops.com/dc=example,dc=com

Pingfederate console:
https://k8s-icecream.ping-devops.com/pingfederate/app

OAuthPlayground:
https://k8s-icecream.ping-devops.com/OAuthPlayground

Pingaccess console:
https://k8s-icecream.ping-devops.com

Kibana console:
https://logs.k8s-icecream.ping-devops.com
```

Information to access the environments may be found here:
```
https://github.com/pingidentity/pingidentity-devops-getting-started/tree/master/11-docker-compose/03-full-stack
```