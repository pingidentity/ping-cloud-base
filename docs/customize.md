# Customize the configuration

You can use the K8s configuration files as a base for a deployment by simply providing a `kustomization.yaml` file similar to this:

```yaml
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1

resources:
- https://github.com/pingidentity/ping-cloud-base/k8s-configs?ref=master
```

You'll need to specify some overrides (such as, through secret and configmap generators) for the DevOps registration credentials and the Ingress URLs. Refer to the `kustomization.yaml` file in the root of this repository for how this can be done. See [kustomize](https://kustomize.io/) for more information.

You can then build a new K8s environment by running:

```bash
kustomize build . | kubectl apply -f -
```

> The manifest files require kustomize v3.1.0 or later. The kustomize that's included in kubectl is an older version. So, currently a direct invocation from kubectl (such as `kubectl apply -k .`) will not work.
