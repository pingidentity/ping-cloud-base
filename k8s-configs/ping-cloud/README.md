# Summary

This directory contains all the base Kubernetes configuration files that may be
used to deploy the Ping Cloud software stack onto a Kubernetes cluster.

# Customization

The configuration in this repository may be used as a base for any customer
deployment by simply providing a kustomization.yaml file that looks like this:

```
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1

resources:
- https://gitlab.corp.pingidentity.com/ping-cloud-private-tenant/ping-cloud-base/k8s-configs?ref=master
```

In addition, some overrides must be provided (e.g. via secret and configmap
generators) for the DEVOPS user/key and the ingress URLs at a minimum. The
tests/kustomize directory shows an example of how this can be done. Then, a new
environment may simply be created by running:

```
kubectl apply -k .
```
