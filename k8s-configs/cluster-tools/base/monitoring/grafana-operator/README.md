This grafana-operator manifests generated with 

```shell
flux pull artifact oci://ghcr.io/grafana-operator/kustomize/grafana-operator:v5.0.1 --output k8s-configs/cluster-tools/base/monitoring/grafana-operator
```

# Updating

Use code snippet and replace version 
```shell
flux pull artifact oci://ghcr.io/grafana-operator/kustomize/grafana-operator:v5.0.2 --output k8s-configs/cluster-tools/base/monitoring/grafana-operator
```

When updating compare changes before pulling the artifacts, and do not override existing manifests.
Example: https://github.com/grafana-operator/grafana-operator/compare/v5.0.1...v5.0.2

If there's no CRD updates - we can only update image.

More information in confluence https://pingidentity.atlassian.net/wiki/spaces/PDA/pages/185139201/Grafana+and+grafana-operator