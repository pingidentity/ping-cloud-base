### 1.19.2.0

_Changes:_

- [X] PDO-7195 Alert when the PF connection to the datastore is lost or fails
- [X] PDO-8196 Include the Fluent Bit ingestion time field in the customer pipeline
- [X] PDO-8355 Cronjob delete Job and PersistentVolumeClaim resources for PingDirectory backups
- [X] PDO-8356 OpenSearch: Increase SC1 (warm) volume size
- [X] PDO-8362 OpenSearch: Add app_timestamp field
- [X] PDO-8363 OpenSearch: Add the Fluent Bit ingestion time field
- [X] PDO-8404 Integrate Logstash and OpenSearch Config into container Image
- [X] PDO-8730 Prevent customer-p1-connection job from running on upgrades
- [X] PDO-8737 Force PingDirectory backup to run once at a time
- [X] PDO-8783 Set AsyncRoot level to "INFO" in PF log4j2.xml file
- [X] PDO-8825 Prometheus: Drop unused metrics
- [X] PDO-8843 FluentBit: Fix multiline parsing config for certain logs

### 1.19.1.0

_Changes:_

- [X] PDO-5864 Add job and secret for connection between customer PingOne and shared PingOne
- [X] PDO-6306 Update jetty-runtime.xml for PingFederate v11.3.7
- [X] PDO-6332 Remove all thread count limits from PingDirectory
- [X] PDO-6661 Remove Cronjob / Job for PingDataSync
- [X] PDO-7238 Remove KMS Init Container from PingDirectory
- [X] PDO-7348 PF transaction log parsing improvements
- [X] PDO-7394 Remove Grafana dashboards from secondary region
- [X] PDO-7434 Update Logstash HPA
- [X] PDO-7461 Updated Prometheus CPU and memory limits and kustomize settings
- [X] PDO-7489 Updates to decrease ContainerInsights
- [X] PDO-7522 Fix autoscaling resource version to use v2
- [X] PDO-7528 Making Graviton as default for NON-GA environment, fix GA consistency across envs
- [X] PDO-7530 Implement permanent reduction of OS resources in 1.19.1
- [X] PDO-7548 Add 'source cluster' identifier to graphs legend for Volume Autoscaler dashboard 
- [X] PDO-7606 Updated Fluent Bit resource to successfully flush records when under minimal load 
- [X] PDO-7570 Logstash: Update config to include K8s resource labels
- [X] PDO-7703 Logstash: Revisit PodDisruptionBudget
- [X] PDO-7742 NewRelic: Optimize Metric Collection by Removing Unnecessary Data Points
- [X] PDO-7759 Increase NR interval to 30s
- [X] PDO-7768 Add customer-defined name to external IdP
- [X] PDO-7772 Nginx ocsp integration test in ping-cloud-base causing instability
- [X] PDO-7788 customer-p1-connection job suspension prevents ArgoCD app healthy status
- [X] PDO-7789 Obfuscate client secret within oidc.properties.subst for PingFederate
- [X] PDO-7804 Create aggregate handler to support pluggable pass-through authentication plugins
- [X] PDO-7805 Remove application/node logs from CloudWatch
- [X] PDO-7806 added additional labels in logstash config
- [X] PDO-8072 ingress-nginx to use topologySpreadConstaints
- [X] PDO-8071 Remove Logstash pipelines for Newrelic
- [X] PDO-8128 Correct sample patch for Pingaccess-WAS engine HPA min/max replicas
- [X] PDO-8164 OpenSearch: Implement Version 2.11.1
- [X] PDO-8190 Update to include ingresses metrics
