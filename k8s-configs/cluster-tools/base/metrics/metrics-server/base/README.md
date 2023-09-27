# Metrics Server Yaml
The base yaml is obtained from:
https://github.com/kubernetes-sigs/metrics-server/tree/master/manifests/base

Run `./update-metrics-server.sh NEW_VERSION` to upgrade files

Example:
Step1: `cd k8s-configs/cluster-tools/base/metrics/metrics-server/base`
Step2: `./update-metrics-server.sh 0.6.4`
