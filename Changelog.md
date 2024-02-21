# Changelog

### v1.18.1.0

- Patch PF admin test environment memory and cpu limits to 4Gi
- Add logstash Disruption Budget to avoid logstash outages during upgrade
- Add pod-reaper annotations to the fluentbit DS
- [EKS 1.28] autoscaling/v2beta2 API version of HorizontalPodAutoscaler is no longer served
- Update kube-state-metrics cluster tool to v2.10.1
- Update kubectl to 1.27.10 for EKS 1.28
- Update cluster-autoscaler v1.29.0 for eks 1.28
- Fix the "pingfederate-cluster" service label selector
- [EKS 1.28] service.alpha.kubernetes.io/tolerate-unready-endpoints (deprecated)
- [EKS 1.28]  Freeze k8s.gcr.io image registry
- ArgoCD Partner and PS Access via config-team
- Add manual healthchecks feature flag
- Update ingress controller to v1.9.6
- Update ArgoCD to v2.10.0

_Changes:_

- [X] Patch PF admin test environment memory and cpu limits to 4Gi
- [X] PDO-6602 Healthcheck feature is available when the feature flag is turned on
- [X] PDO-6608 Add logstash Disruption Budget
- [X] PDO-6628 Add pod-reaper annotations to the fluentbit DS
- [X] PDO-6668 ArgoCD Partner and PS Access via config-team
- [X] PDO-6712 Metadata is missing in NewRelic pod logs
- [X] PDO-6715 [EKS 1.28] autoscaling/v2beta2 API version of HorizontalPodAutoscaler is no longer served
- [X] pdo-6716 [EKS 1.28]  Freeze k8s.gcr.io image registry
- [X] PDO-6717 [EKS 1.28] service.alpha.kubernetes.io/tolerate-unready-endpoints (deprecated)
- [X] PDO-6718 Upgrade ingress controller to v1.9.6
- [X] PDO-6719 Upgrade argocd to v2.9+  for EKS 1.28
- [X] PDO-6720 Update kube-state-metrics cluster tool to v2.10.1
- [X] PDO-6721 Update kubectl to 1.27.10 for EKS 1.28
- [X] PDO-6723 Update cluster-autoscaler v1.29.0 for eks 1.28
- [X] PDO-6750 Fix the "pingfederate-cluster" service label selector

v1.18.0.0

**Ping Identity Products**

_[Key Features]_
- Enable users to download or upload user reports in Delegated Admin
- Backup monitor history everyday for PingDirectory
- Disable backend priming at the start of PingDirectory
- Execute backup and restore within is own Persistent Volume for PingDirectory
- Increase PingFederate Max Thread Count

_[Upgrades]_
- Upgraded PingDataSync to v9.2.0.0
- Upgraded PingDirectory to v9.2.0.4
- Upgraded PingFederate to v11.3.3

**Observability and Monitoring**

_[Key Features]_
- Parsing improvement: Multi-line logs generated from server.log (PingFederate) now appear in Kibana as a single document
- Legacy logging mode (sending logs to Cloudwatch) has been fully removed. Logs now sent to ELK (and optionally to customer endpoint)
- Kibana (1.18 only): When searching indexes, results contain the same fields and data, regardless of index chosen, for example pf-audit* vs logstash*
- ElasticSearch: Added horizontal pod autoscaler; logstash performs much better under load.
- ElasticSearch: Warm nodes count has been increased to three (survives AZ failure; more performant)
- Fluentbit: Now leverages IMDSv2 security instead of IMDSv1
- Prometheus: Alerts are sent to OpsGenie
- Grafana: Logging and Alert Metrics are available (only) to internal teams
- Grafana: User authorization provides separate customer and internal teams view

**Platform and Underlying Tools**

_[Key Features]_
- ArgoCD is now only deployed to customer-hub, managing dev/test/stage/prod (one per region)
- Allow users to pick and enable only the external ingress they want
- StorageClass provisioner changed to CSI and EBS type to changed to GP3
