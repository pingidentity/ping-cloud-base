# Changelog

### 1.19.0.0

- Create a new init container to upgrade PA and PA-WAS and mount volume to admin pod once upgrade is successful
- Update bootstrap to create davinci-configuration secret
- Add new seal secrets script for MonoRepo breakup
- Updating kustomize build options within ArgoCD to support Helm
- Fix: kubernetes-dashboards configmap "Too long" error
- Replace ElasticSearch and Kibana by OpenSearch stack
- Add OpenSearch monitoring and alerting
- Improve logstash grok patterns to prevent execution timeouts
- Add resource (cpu & memory) limit and request for every product Job and Cronjob
- Update prometheus alerts with links to the runbooks
- Added new Prometheus alerts for Kubernetes metrics
- Update integration tests to handle SSM parameters, rather than an explicit s3 bucket prefix
- Update nginx-ingress-controller to v1.6.4 to support EKS 1.26
- Create new RBAC rules , ping role and service accounts for PD backups and restore
- Update PD backup/restore integration tests
- Configure Lifecycle policy for PingFederate Engines
- Update kube-state-metrics to v2.8.1
- Move S3, CloudWarch, Newrelic outputs from Fluentbit to Logstash pipelines
- Mirror our own version of newrelic images
- [need before EKS 1.26] autoscaling/v2beta2 API version of HorizontalPodAutoscaler is no longer served as of v1.25
- Update PGO dashboards to use grafana CRD

_Changes:_

- [X] PDO-4606 Create a new init container to upgrade PA and PA-WAS and mount volume to admin pod once upgrade is successful
- [X] PDO-4779 Modify seal.sh script to work for microservices
- [X] PDO-5110 OpenSearch migration: Install Opensearch side-by-side with Elastic
- [X] PDO-5112 OpenSearch migration: Migrate index templates
- [X] PDO-5113 OpenSearch migration: Change logstash pipelines to send data to OS instead ES
- [X] PDO-5114 OpenSearch migration: Migrate PA dashboard
- [X] PDO-5116 OpenSearch migration: Migrate PF dashboards
- [X] PDO-5145 OpenSearch migration: Develop index migration job
- [X] PDO-5152 OpenSearch migration: Rewrite bootstrap scripts
- [X] PDO-5158 Configure PA WAS from Shared P1 Tenant
- [X] PDO-5244 OpenSearch migration: Enable transport layer security
- [X] PDO-5245 OpenSearch migration: Update grafana dashboards datasource
- [X] PDO-5246 Opensearch migration: Migrate alerts
- [X] PDO-5249 [need before EKS 1.26] autoscaling/v2beta2 API version of HorizontalPodAutoscaler is no longer served as of v1.25
- [X] PDO-5254 Move all external outputs from Fluentbit to Logstash pipelines
- [X] PDO-5258 OpenSearch migration: Refactor bootstrap scripts
- [X] PDO-5270 Replace all  long alerts descriptions by short ones with links to runbook
- [X] PDO-5301 Logstash: Improve grok patterns to prevent execution timeouts
- [X] PDO-5307 OpenSearch migration: Implement Monitoring
- [X] PDO-5314 Update bootstrap to create davinci-configuration secret
- [X] PDO-5320 BUGFIX: found_distance_alert and other found* fields are not present in pf-audit* index documents
- [X] PDO-5333 ArgoCD authentication to private ECR for Helm
- [X] PDO-5358 OpenSearch Migration: Refactor OS Code as Needed
- [X] PDO-5371 Update PCB Pipeline to deploy CDE dev Environment
- [X] PDO-5396 Create new RBAC rules , ping role and service accounts for PD backups and restore 
- [X] PDO-5400 Update PD backup/restore integration tests
- [X] PDO-5408 Add boolean flag to skip pod liveness probe script for PingFederate engines, PingAccess/WAS engines, and PingDirectory
- [X] PDO-5409 Add ability to Update Upgrade Scripts w/o Release of New Beluga Version
- [X] PDO-5418 Add resource (cpu & memory) limit and request for every product Job and Cronjob
- [X] PDO-5435 Update values.yaml files structure
- [X] PDO-5467 When rolling pods NLB connection draining isn't occuring causing service interruption
- [X] PDO-5543 New Prometheus alerts for Kubernetes metrics
- [X] PDO-5549 Update kube-state-metrics cluster tool to v2.8.1 for EKS 1.26
- [X] PDO-5558 Mirror our own version of newrelic images
- [X] PDO-5571 Update nginx-ingress-controller to v1.6.4 to support EKS 1.26
- [X] PDO-5601 os-dashboar
