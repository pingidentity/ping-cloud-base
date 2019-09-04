# Ping Cloud Base Configuration

This directory contains all the base Kubernetes configuration files that may be
used to deploy the Ping Cloud software stack onto a Kubernetes cluster. It
allows anyone to set up a cookie-cutter Ping Software stack on a Kubernetes
cluster for evaluation purposes. Currently only AWS EKS clusters are supported.

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

https://docs.google.com/forms/d/e/1FAIpQLSdgEFvqQQNwlsxlT6SaraeDMBoKFjkJVCyMvGPVPKcrzT3yHA/viewform

The TENANT_DOMAIN must be an AWS registered domain and hosted zone on Route53 in
the same AWS IAM role (e.g. arn:aws:iam::574076504146:role/GTE) as your EKS
cluster. For example, if it is set to k8s-icecream.ping-devops.com, then
ping-devops.com must be a valid DNS domain registered by some registrar (e.g.
AWS Route53). There must also be a hosted zone created for it on AWS Route53.
Refer to the AWS online documentation on how to set these up.

To build the environment, simply run:

```
kustomize build https://github.com/pingidentity/ping-cloud-base/test?ref=master | envsubst | kubectl apply -f -
```

Monitor it by running:
```
kubectl get pods -n ping-cloud
```

When all pods are ready, you should be able to access the following URLs:

```
Pingdirectory console:
https://pingdataconsole.k8s-icecream.ping-devops.com/console

Pingfederate console:
https://pingfederate.k8s-icecream.ping-devops.com/pingfederate/app

Pingfederate authorization server endpoints:
https://pingfederate.k8s-icecream.ping-devops.com

Pingaccess console:
https://pingaccess.k8s-icecream.ping-devops.com

Kibana console:
https://logs.k8s-icecream.ping-devops.com
```

Information on how to access the environments may be found here:

https://github.com/pingidentity/pingidentity-devops-getting-started/tree/master/11-docker-compose/03-full-stack

# Customization

The configuration in this repository may be used as a base for any customer
deployment by simply providing a kustomization.yaml file that looks like this:

```
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1

resources:
- https://github.com/pingidentity/ping-cloud-base/k8s-configs?ref=master
```

In addition, some overrides must be provided (e.g. via secret and configmap
generators) for the DEVOPS user/key and the ingress URLs at a minimum. The
test directory shows an example of how this can be done. Then, a new environment
may simply be created by running:

```
kustomize build . | kubectl apply -f -
```

Note that the manifest files only work with kustomize v3.1.0 or later. The
kustomize that's included in kubectl is of an older version. So the following
direct invocation from kubectl does not work at the moment.

~~kubectl apply -k .~~


