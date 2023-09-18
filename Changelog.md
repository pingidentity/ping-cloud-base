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
- Update prometheus alerts with links to the runbooks
- Added new Prometheus alerts for Kubernetes metrics
- Update integration tests to handle SSM parameters, rather than an explicit s3 bucket prefix
- Update nginx-ingress-controller to v1.6.4 to support EKS 1.26
- Automate a test to ensure passwords dont leak in pod logs
- Create new RBAC rules , ping role and service accounts for PD backups and restore
- Update PD backup/restore integration tests
- Configure Lifecycle policy for PingFederate Engines
- Update kube-state-metrics to v2.8.1
- Move S3, CloudWarch, Newrelic outputs from Fluentbit to Logstash pipelines
- Mirror our own version of newrelic images
- [need before EKS 1.26] autoscaling/v2beta2 API version of HorizontalPodAutoscaler is no longer served as of v1.25
- Update PGO dashboards to use grafana CRD
- [EKS 1.26] service.alpha.kubernetes.io/tolerate-unready-endpoints (deprecated)
- Add CW Agent IRSA role
- Update PCB with toolkit image used as replacement for bitnami/kubectl
- Modified git-ops-command.sh script to handle the SIGTERM signal appropriately.
- Upgrade Kustomize to 5.0.3
- Re-enable PingCentral for CI/CD dev environments which are now deployed using generate-cluster-state.sh
- Migrated 'profiles' directory away from root of PCB, and into 'code-gen' root dir.  Also removed 'aws' subdir.
- Improve alerts. JSON format + link to runbook
- Limit backup/restore logging for PD
- enrichment-bootstrap Docker image scripts refactoring
- Change PD alerts to see more specific errors
- Update pd.profile to align with PingDirectory upgrade
- Update cluster-autoscaler v1.27.0/1.27.1 for eks 1.27
- Update nginx-ingress-controller to v1.8.0 to support EKS 1.27
- Healthcheck pods respond properly to SIGTERM
- Update PCB with new Radius Proxy Image
- Unify severity format for all prometheus alerts
- Add p1as-beluga-tools microservice to PCB
- Create PD init container for KMS
- CloudWatch / New Relic: Disable logging for Dev clusters
- Enabling weekend scheduled runs to different CDE types (dev/test/stage/prod/customer-hub)
- Fix: opensearch-bootstrap job in a second region can't connect to OpenSearch
- Update OpenSearch/OpenSearch Dashboards to v2.8.0
- Update AWS EFS CSI Driver to v1.5.8 & set requests/limits
- Update alertmeneger image with self-hosted ECR URI
- Update fluent-bit image with v2.1.8
- Logstash pipelines refactored
- Support DHE Ciphers out of the box
- Argo CD log level changed to 'ERROR'
- external-dns pod log level changed to 'ERROR'
- Opensearch cluster log level changed to 'WARNING'
- Update metrics-server image to v0.6.4
- Update kubectl to 1.26.0 for EKS 1.27
- Update kube-state-metrics to v2.9.2
- Remove dev-env.sh, dev-cluster-state (dir), and corresponding variables.
- Update Grafana to v10.1.0
- Update Alertmanager to v0.26
- Add Karpenter capacity and performance Grafana dashboard
- Add fluent-bit input filter to Karpenter logs 
- Update Amazon-Cloudwatch-agent to v1.300026.3b189
- Update EBS Driver to 1.21.0 for EKS 1.27
- Update newrelic-java-agent to v8.6.0
- Add oidc.properties.subst to profile repo
- Upgrade sealed secrets controller to v0.23+
- Fix common integration tests
- Update csr-valdation.sh to create a single .yaml file per microservice, rather than directory

_Changes:_

- [X] PDO-3541 Support DHE Ciphers out of the box
- [X] PDO-4264 Upgraded karpenter to v0.29.2 and adjusted its config to integrate with platform resource.
- [X] PDO-4606 Create a new init container to upgrade PA and PA-WAS and mount volume to admin pod once upgrade is successful
- [X] PDO-4779 Modify seal.sh script to work for microservices
- [X] PDO-4847 Add weekly pipeline run logic for PCB
- [X] PDO-4857 Add Beluga Tools code-gen directory to PCB
- [X] PDO-4868 Update update-cluster-state script for MonoRepo
- [X] PDO-4896 Update ping-cloud-base karpenter version to v0.28.1
- [X] PDO-5005 Update generate-cluster-state script to pull profiles from code-gen dir
- [X] PDO-5110 OpenSearch migration: Install Opensearch side-by-side with Elastic
- [X] PDO-5112 OpenSearch migration: Migrate index templates
- [X] PDO-5113 OpenSearch migration: Change logstash pipelines to send data to OS instead ES
- [X] PDO-5114 OpenSearch migration: Migrate PA dashboard
- [X] PDO-5116 OpenSearch migration: Migrate PF dashboards
- [X] PDO-5135 Implement IRSA role for aws cloud watch agent
- [X] PDO-5145 OpenSearch migration: Develop index migration job
- [X] PDO-5152 OpenSearch migration: Rewrite bootstrap scripts
- [X] PDO-5158 Configure PA WAS from Shared P1 Tenant
- [X] PDO-5159 Configure PF Admin SSO from Shared P1 Tenant flow
- [X] PDO-5164 [EKS 1.26] service.alpha.kubernetes.io/tolerate-unready-endpoints (deprecated)
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
- [X] PDO-5373 PingCentral testing in PCB Pipeline CDE deployment
- [X] PDO-5378 Automate a test to ensure passwords dont leak in pod logs
- [X] PDO-5396 Create new RBAC rules , ping role and service accounts for PD backups and restore 
- [X] PDO-5400 Update PD backup/restore integration tests
- [X] PDO-5408 Add boolean flag to skip pod liveness probe script for PingFederate engines, PingAccess/WAS engines, and PingDirectory
- [X] PDO-5409 Add ability to Update Upgrade Scripts w/o Release of New Beluga Version
- [X] PDO-5434 Upgrade Kustomize to 5.0.3
- [X] PDO-5435 Update values.yaml files structure
- [X] PDO-5695 Move alertmanager image to self-hosted ECR
- [X] PDO-5467 When rolling pods NLB connection draining isn't occuring causing service interruption
- [X] PDO-5527 OpenSearch Post-Migration: Alerting improvements
- [X] PDO-5528 Logstash: Refactor Main Pipeline
- [X] PDO-5543 New Prometheus alerts for Kubernetes metrics
- [X] PDO-5545 Change PD alerts to see more specific errors
- [X] PDO-5549 Update kube-state-metrics cluster tool to v2.8.1 for EKS 1.26
- [X] PDO-5558 Mirror our own version of newrelic images
- [X] PDO-5571 Update nginx-ingress-controller to v1.6.4 to support EKS 1.26
- [X] PDO-5601 os-dashboards-pf configMap breaks developer, and new ci/cd deploys
- [X] PDO-5647 Handle SIGTERM properly in enrichment-bootstrap
- [X] PDO-5654 Fluentbit Kubernetes filter is not adding metadata into some events
- [X] PDO-5655 OS: Logs for the pf-transaction-* index are not filtered
- [X] PDO-5659 git-ops-command.sh responds properly to SIGTERM
- [X] PDO-5660 Healthcheck pods respond properly to SIGTERM
- [X] PDO-5671 OS: grokparsefailure in pingaccess logs
- [x] PDO-5673 OS: Missed logs in PingAccess Indices
- [X] PDO-5680 Implement a solution for ArgoCD CRD race condition
- [X] PDO-5705 Update PCB with toolkit image used as replacement for bitnami/kubectl
- [X] PDO-5707 Remove dev-env.sh and dev-cluster-state from PCB
- [X] PDO-5709 Fix intermittent pingone integration test failures
- [X] PDO-5718 Update PGO dashboards to use grafana CRD
- [X] PDO-5724 Limit backup/restore logging for PD
- [X] PDO-5741 OS: Index migration fails for shrink-*-logstash-* indexes
- [X] PDO-5781 Update nginx-ingress-controller to v1.8.0 to support EKS 1.27
- [X] PDO-5762 CloudWatch / New Relic: Disable logging for Dev clusters
- [X] PDO-5770 Update update-profile-repo script for MonoRepo
- [X] PDO-5774 OS Index Policies: State Transitions Errors
- [X] PDO-5780 Update kubectl to 1.26.0 for EKS 1.27
- [X] PDO-5785 Update kube-state-metrics cluster tool to v2.9.2
- [X] PDO-5789 Upgrade sealed secrets controller to v0.23+
- [X] PDO-5797 Unify severity format for all prometheus alerts
- [X] PDO-5800 Update pd.profile to align with PingDirectory upgrade
- [X] PDO-5801 Update cluster-autoscaler v1.27.0/1.27.1 for eks 1.27
- [X] PDO-5803 Update EBS Driver to 1.21.0 for EKS 1.27
- [X] PDO-5813 Remove excessive patches for the second region
- [X] PDO-5835 Create PD init container for KMS
- [X] PDO-5871 Update AWS EFS CSI Driver to v1.5.8
- [X] PDO-5873 Update OpenSearch/OSD to v2.8.0
- [X] PDO-5874 Migrate from AWS-for-fluent-bit to fluent-bit v2.1.8
- [X] PDO-5875 Update Grafana to v10.1.0
- [X] PDO-5876 Update Amazon-Cloudwatch-agent to v1.300026.3b189
- [X] PDO-5877 Update metrics-server to v0.6.4
- [X] PDO-5878 Update newrelic-java-agent to v8.6.0
- [X] PDO-5881 Update Alertmanager to v0.26
- [X] PDO-5923 Karpenter capacity and performance Grafana dashboard
- [X] PDO-5924 Multi-Region CDE: opensearch-bootstrap job in a second region can't connect to OpenSearch
- [X] PDO-5972 Karpenter Pods: Verify Logs are sent to CloudWatch
- [X] PDO-6006 Change Argo CD log to 'ERROR' level
- [X] PDO-6007 Change external-dns pod log to 'ERROR' level
- [X] PDO-6008 Change Opensearch log to 'WARNING' level
- [X] PDO-6061 Fix pingone-configurator pod crashing when missing ConfigMap ping-cloud/is-pingone
- [X] PDO-6077 Multiple issues with OpenSearch connect from secondary region
- [X] PDO-6136 Fix common integration tests

### 1.18.0.0

- Enable users to download or upload user reports in Delegated Admin
- Upgrade ArgoCD to v2.5.5
- Upgrade nginx-ingress-controller to v1.5.1
- Add base & region values.yaml files for Helm migration
- Update values.yaml in region and base path sync with env_vars file
- Add ArgoCD application set definition for microservice architecture
- Update sealed-secrets-controller to v0.19.3
- Add multiple USER_BASE_DNs and BACKEND_IDs env vars
- Add multiple backends to 'BACKENDS_TO_BACKUP' env var
- Selectively restore a backend in PD
- Capture hourly PingDirectory CSD data
- Enable and manage daily encrypted exports
- Updated external-dns to v0.13.1 
- Update cluster tools to latest version: kube-state-metrics v2.6.0
- Remove PA/PF SIEM console logging
- Updated cluster-autoscaler to v1.23.0
- Upgrade Grafana to v9.3.6
- Upgrade prometheus to v2.42.0
- Upgrade EFS Driver to v1.5.1
- Add PF requests logs parsing and indexing
- Fix index template creation race condition issue
- Change retry interval for PGO firing alert notification in slack from 5 min to 60 min
- Added karpenter v0.24.0 and required parameters, KarpenterControllerRole & ClusterEndPoint
- ILM policy for alerts index changed to move index to warm after 7 days in hot and delete index after 30 days
- Add PA-WAS to customer-hub env
- Replace deprecated topologyKey
- Enable the skipped integration tests.
- Automate creation of ping-cloud-dashboards new release branch 
- Update cluster tools to latest version: metrics-server v0.6.2
- Update all PodDisruptionBudget resources to API v1
- [need before EKS 1.25] batch/v1beta1 CronJob is deprecated in v1.21+, unavailable in v1.25+; use batch/v1 CronJob
- Remove node-role.kubernetes.io/master (deprecated)
- Update cluster tools to latest version: newrelic java agent to v8.0.1
- Update newrelic-infrastructure images
- Update cluster tools to latest version: cloudwatch-agent to v1.247357.0
- Update tagging script to return correct tag
- Add logstash HPA and upgrade resources
- Add init container for ArgoCD to create clusters for itself
- Add ArgoCD Applications for each CDE via ApplicationSet
- Remove LEGACY_LOGGING flag and logic
- Update Prometheus CPU/MEM limits
- Add ArgoCD ApplicationSet support for multiple CDEs
- Flag in env_var to enable/disable external ingresses for admin endpoints
- Fix test that file has been copied is not working in init container
- Update default version of pf-pingid-integration-kit to 2.24.0 in PingFederate
- Deploy ArgoCD to customer-hub only
- Fix the ArgoCD App name
- Add ArgoCD IRSA role
- Modify Prometheus query for all backup alerting to only include the primary pod
- Improve fluent-bit multiline log parsing
- Updated StorageClass provisoner to CSI and type to gp3
- Add logstash and fluent-bit metrics to prometheus
- Enable bootstrapping a new customer with ArgoCD
- Add a new hook script '02-health-check.sh' to support readiness and liveness probes
- Add logstash/fluent-bit readiness/liveness probe
- Add priorityClassName into CWAgent daemonset
- Fluent-bit pods stuck in pending state
- Create new folders "Backup-ops-template" "restore-ops-template" for PD backups,restore process
- Add logstash and fluent-bit alerts
- Fix Kibana Visualization "Ping Access - Response Codes Over Time"
- No longer move files into custom-resources directory when upgrading
- Set 7-day-retention policy to all backup jobs logs
- Configure Fluent-bit kubernetes filter to prevent caching for statefulsets
- New base configuration for PingDirectory permissions
- Replace PodSecurityPolicy as it will no longer be served in EKS v1.25
- Allow configuration of certain ArgoCD values per-CDE
- Replaced PSA privileged policy by more restricted policies for newrelic components
- Update kube-state-metrics to v2.7.0
- Bug fix, remove-from-secondary-patch.yaml not getting applied
- Remove healthchecks for undeployed products in customer-hub
- Default ngnix hpa configuration in medium environment is lower than small
- Fix cluster_name variable in Grafana Dashboards for CHUB
- Remove PC resources from secondary customer-hub
- Allow users to pick and enable only the external ingress they want. 
- Fixed Pending state of nri-bundle-nrk8s-kubelet pods running by CDE
- Add pingaccess-was-license secret placeholder entry to CHUB
- Increase replica count (min=7, max=9) within prod/large for Nginx Ingress Controller
- Backup monitor history everyday for PingDirectory
- Create backends dynamically through manage-profile for PingDirectory
- PA-WAS ext ingress is missing from non-customer-hub environments
- Update kubectl to 1.24.0 for EKS 1.25
- Update cert-manager to v1.11.2 for EKS 1.25
- Upgrade Postgres Operator (PGO) to 5.3.1 to support EKS v1.25
- Add PGO Backups Jobs TTL
- Add region env vars to cluster-health-environment-variables configmap
- Auto update LAST_UPDATE_REASON within app env_vars on upgrade
- Update healthcheck configmaps to include primary region admin API pod names
- Update PingAccess configmap patch to include HEALTHCHECK_HTTPBIN_PA_PUBLIC_HOSTNAME
- Add BACKENDS_TO_RESTORE variable to restore-op.sh script for running PingDirectory restore job
- Backup scripts notifications are enabled by default
- Update healthcheck-httpbin-pa and healthcheck-httpbin-pa-was hostnames to use PRIMARY_DNS_ZONE
- Remove healthcheck-httpbin-pa from child regions
- Remove integration kits from PingFederate deployment (excluding pf-pingid) and upgrade opentoken-adapter to v2.7.2
- Add REGION env var for healthcheck probes in customer hub
- Fix IRSA role for pingfederate-admin-serviceaccount
- Add "--skipPrime" flag to PD start-server script
- Upgrade PingFederate to v11.3.1
- Update PA-WAS admin/engine CSD upload job to reference PA-WAS CSD upload configMaps, rather than just pingaccess.  
- Fluent-Bit: change IMDS vesrion to v2
- Remove docker logs from fluent-bit
- Remove unneeded OS\Grafana dashboards from CHUB

_Changes:_

- [X] PDO-2419 Enable users to download or upload user reports in Delegated Admin
- [X] PDO-3335 Set PingFederate Engines minReplicas count to 3 in prod/small deployment
- [X] PDO-3834 Updated StorageClass type to gp3
- [X] PDO-3908 Clean up P1 artifacts in Admin environment during CI/CD teardown
- [X] PDO-4009 Update k8s StorageClass provisoner to use CSI driver
- [X] PDO-4161 [need before EKS 1.25] Replace PodSecurityPolicy as it will no longer be served in EKS v1.25
- [X] PDO-4257 Capture hourly PingDirectory CSD data
- [X] PDO-4258 Enable and manage daily encrypted exports
- [X] PDO-4259 Backup monitor history everyday for PingDirectory
- [X] PDO-4309 Add integration test for PingDirectory Java args
- [X] PDO-4388 Flag in env_var to enable/disable external ingresses for admin endpoints
- [X] PDO-4548 Find and destroy file moving to custom-resources code from generate-cluster-state.sh to fix reoccuring issue when upgrading
- [X] PDO-4556 [need before EKS 1.25] batch/v1beta1 CronJob is deprecated in v1.21+, unavailable in v1.25+; use batch/v1 CronJob
- [X] PDO-4575 Upgrade ArgoCD to v2.5.5
- [X] PDO-4697 Update cluster tools to latest version: cluster-autoscaler v1.23.0
- [X] PDO-4698 Upgrade nginx-ingress-controller to v1.5.1
- [X] PDO-4701 Update cluster tools to latest version: sealed-secrets-controller v0.19.3
- [X] PDO-4702 Update cluster tools to latest version: external-dns v0.13.1
- [X] PDO-4705 Update cluster tools to latest version: kube-state-metrics v2.6.0
- [X] PDO-4706 Update cluster tools to latest version: metrics-server v0.6.2
- [X] PDO-4709 Update cluster tools to latest version: Grafana v9.3.6
- [X] PDO-4713 Update cluster tools to latest version: prometheus to v2.42.0
- [X] PDO-4714 Update cluster tools to latest version: newrelic-infrastructure
- [X] PDO-4715 Update cluster tools to latest version: newrelic java agent to v8.0.1
- [X] PDo-4716 Update cluster tools to latest version: cloudwatch-agent to v1.247357.0
- [X] PDO-4765 Disable the CloudWatch Agent in development environments and development CDEs
- [X] PDO-4773 Update generate-cluster-state script to create base and region values.yaml files
- [X] PDO-4774 Update generate-cluster-state script to massage the new code-gen structure files into the new CSR structure
- [X] PDO-4775 Add new ArgoCD application definition to PCB
- [X] PDO-4777 Create gitlab-ci for CSR
- [X] PDO-4780 Move tag-release.sh and PCB ci-scripts to shared location
- [X] PDO-4817 Remove SIEM console logging for PA/PF
- [X] PDO-4818 Add multiple USER_BASE_DNs and BACKEND_IDs env vars
- [X] PDO-4822 Add multiple backends to 'BACKENDS_TO_BACKUP' env var
- [X] PDO-4835 Update all PodDisruptionBudget resources to API v1
- [X] PDO-4836 Copy PCD ci-scripts to shared location
- [X] PDO-4861 Selectively restore a backend in PD
- [X] PDO-4870 Enable the skipped integration tests.
- [X] PDO-4874 Automate creation of ping-cloud-dashboards new release branch
- [X] PDO-4895 Added karpenter v0.24.0 and required parameters, KarpenterControllerRole & ClusterEndPoint
- [X] PDO-4902 Code sharing for PingOne deployments
- [X] PDO-4903 Deploy PingOne in CICD like Shared P1 Tenant
- [X] PDO-4916 Missing PF request log
- [X] PDO-4974 Change retry interval for PGO firing alert notification in slack from 5 min to 60 min
- [X] PDO-4980 Index lifecycle error: illegal_argument_exception: policy [healthchecks] does not exist
- [X] PDO-4981 Index templates are not applied to indexes in case elastic-stack-logging ns respinned
- [X] PDO-4982 Update cluster tools to latest version: EFS Driver to v1.5.1
- [X] PDO-4983 Index lifecycle error: illegal_argument_exception: policy [ping-2-day-retention] does not exist
- [X] PDO-4986 Add PA-WAS in customer-hub
- [X] PDO-4987 Add ArgoCD Bootstrap init container to create clusters
- [X] PDO-4988 Add ArgoCD Applications for each CDE via ApplicationSet
- [X] PDO-4989 Add ArgoCD ApplicationSet support for multiple CDEs
- [X] PDO-4990 Add ArgoCD IRSA role
- [X] PDO-4991 Deploy ArgoCD to customer-hub only
- [X] PDO-4997 Update values.yaml in region and base path sync with env_vars file
- [X] PDO-5008 Update tagging script to return correct tag
- [X] PDO-5009 Add logstash HPA and upgrade resources
- [X] PDO-5017 Use SUPPORTED_ENVIRONMENT_TYPES for generate/update scripts
- [X] PDO-5018 PGO resources - handle secondary region v1.18
- [X] PDO-5025 Improve fluent-bit multiline log parsing
- [X] PDO-5030 New base configuration for PingDirectory permissions
- [X] PDO-5037 Update to replace deprecated topologyKey to topology.kubernetes.io/zone 
- [X] PDO-5039 Automate cleanup of external dns records for CI/CD clusters
- [X] PDO-5041 node-role.kubernetes.io/master (deprecated)
- [X] PDO-5043 Legacy Logging Mode: Remove Feature Flag, Code Logic and Refactor Filters
- [X] PDO-5080 Test that file has been copied is not working in init container
- [X] PDO-5090 Update default version of pf-pingid-integration-kit to 2.24.0 in PingFederate
- [X] PDO-5104 Update Prometheus CPU/MEM limits
- [X] PDO-5107 Fluent-bit pods stuck in pending state
- [X] PDO-5123 Create new folders "Backup-ops-template" "restore-ops-template" for PD backups,restore process
- [X] PDO-5124 Enable bootstrapping a new customer with ArgoCD
- [X] PDO-5131 Pods (typically cloudwatch) Stuck in pending state
- [X] PDO-5138 Add a new hook script '02-health-check.sh' to support readiness and liveness probes 
- [X] PDO-5141 Fix the ArgoCD App name
- [X] PDO-5143 Add logstash and fluent-bit alerts
- [X] PDO-5144 Add logstash/fluent-bit readiness/liveness probe
- [X] PDO-5147 Add logstash metrics to prometheus
- [X] PDO-5148 Modify Prometheus query for all backup alerting to only include the primary pod
- [X] PDO-5191 Update image_map to align with tagging process
- [X] PDO-5217 Increase replica count (min=7, max=9) within prod/large for Nginx Ingress Controller
- [X] PDO-5221 'Field "responseCode.keyword" not found' on the 'Ping Access - Response Codes Over Time' visualization
- [X] PDO-5223 Remove pa-was config for ArgoCD from non customer-hub CDEs
- [X] PDD-5226 Remove integration kits from PingFederate deployment (excluding pf-pingid) and upgrade opentoken-adapter to v2.7.2
- [X] PDO-5232 Configure Fluent-bit kubernetes filter to prevent caching for statefulsets
- [X] PDO-5248 Bug fix,remove-from-secondary-patch.yaml not getting applied
- [X] PDO-5255 Allow configuration of certain ArgoCD values per-CDE
- [X] PDO-5261 Remove PF and PA from pa-was config in customer-hub
- [X] PDO-5262 Allow users to pick and enable only the external ingress they want.
- [X] PDO-5263 Remove PC resources from secondary customer-hub
- [X] PDO-5264 Set 7-day-retention policy to all backup jobs logs
- [X] PDO-5271 Replace PSA privileged policy by more restricted policies for newrelic components if needed
- [X] PDO-5279 Update kube-state-metrics cluster tool to v2.7.0 for EKS 1.25
- [X] PDO-5281 Default ngnix hpa configuration in medium environment is lower than small
- [X] PDO-5288 Update health check. healthcheck should only test the resources that have been deployed
- [X] PDO-5298 Bugfix - make scripts compatible with Debian
- [X] PDO-5302 Fix PF multiline parsing
- [X] PDO-5315 Bugfix - argocd-bootstrap to use region specific env vars
- [X] PDO-5319 The cluster name is not displayed correctly in Grafana Dashboard for the CHUB cluster
- [X] PDO-5328 Add pingaccess-was-license secret placeholder entry to CHUB 
- [X] PDO-5377 Patch CA to balance node across all AZs
- [X] PDO-5390 nri-bundle-nrk8s-kubelet-* pods running by CDE stuck in Pending state
- [X] PDO-5393 Bugfix - secondary CSR missing app dir
- [X] PDO-5410 Auto-Update the Last Update Reason
- [X] PDO-5419 Bugfix - remove monitoring & logging from secondary
- [X] PDO-5415 Bugfix - PA-WAS ext ingress is missing from non-customer-hub environments
- [X] PDO-5433 Update/Disable healthchecks
- [X] PDO-5436 Bugfix - Uneven load distribution among logstash pods
- [X] PDO-5459 Update cert-manager to v1.11.2 for EKS 1.25
- [X] PDO-5460 Update kubectl to 1.24.0 for EKS 1.25
- [X] PDO-5474 upgrade Postgres Operator (PGO) to 5.3.1 to support EKS v1.25
- [X] PDO-5510 Update all healthchecks to use k8s service endpoints
- [X] PDO-5525 Add PGO Backups Jobs TTL
- [X] PDO-5547 Create backends dynamically through manage-profile for PingDirectory
- [X] PDO-5553 Bugfix: remove-from-secondary-patch is broken for logstash-pipeline-alerts
- [X] PDO-5556 Fix PingAccess healthchecks
- [X] PDO-5610 Add BACKENDS_TO_RESTORE variable to restore-op.sh script for running PingDirectory restore job
- [X] PDO-5611 PD Healthchecks include k8s cluster name
- [X] PDO-5614 Bugfix: 'cluster_name' filter issue in ELK and Grafana on prod CDE
- [X] PDO-5646 Warning messages in cert-manager pod logs
- [X] PDO-5648 [PORT PDO-5508] Extend PingDirectory replica count to up to 50 pods per region and 11 base DNs if needed
- [X] PDO-5650 set NOTIFICATION_ENABLED to True by default
- [X] PDO-5690 v1.18 Prepare for Ability to Update Upgrade Scripts w/o Release of New Beluga Version
- [X] PDO-5804 Add REGION env var for healthcheck probes in customer hub
- [X] PDO-5806 Remove unneeded OS\Grafana dashboards from CHUB
- [X] PDO-5815 Fluent-Bit: change IMDS version to v2
- [X] PDO-5832 Add "--skipPrime" flag to PD start-server script
- [X] PDO-5869 Fix IRSA role for pingfederate-admin-serviceaccount
- [X] PDO-5906 Upgrade PingFederate to v11.3.1
- [X] PDO-5911 Update PA-WAS Admin CSD Upload job to use PA-WAS cm
- [X] PDO-6015 Remove docker logs from fluent-bit
- [X] PDO-6078 Exclude dlq pipeline from alerts

### 1.17.0.0

- Remove logstash tolerations
- Argo CD non-root user changes
- Prometheus configured to take metrics from second region
- Prometheus upgraded to 2.39.1
- Create new global repo for dashboards
- Send logs from second region to main Elasticsearch
- Add HTTP server pod for PingAccess-WAS healthchecks
- Add HTTP server pod for PingAccess healthchecks
- Add HTTP server pod for PingFederate healthchecks
- Remove unneeded resources from secondary region
- Retain set value for slack channel alerts
- Added CICD integration health test to check certificate results
- Modified Kibana dashboards to show second region logs and metrics
- Allow release branches to update image names using the kustomize image patch
- Add beluga_log verbosity level to control logging level
- Changed Slack channel for Argo notifications depending on IS_GA value
- Remove "PING_CONTAINER_PRIVILEGED" from env_vars
- Remove EFS access points directories when deleting PV
- NewRelic Java Agent upgraded to 7.11.1
- Refactor elastic-stack manifests
- Remove outdated CW logs test methods
- Add healthcheck-pingdirectory cronjob
- Added k8s serviceAccount for PA, PD & PF
- Update ping-cloud-base to use the cluster tools from new ECR repo
- Configure Argo Redis container to run as nonroot
- Update applications logs location
- Refactor offline-enable script to use "dsreplication enable-with-static-topology" subcommand
- Healthcheck logs now stored in separate index with 7 days retention period
- Upgrade kubectl to match K8s version and bitnami kubectl image.
- Mirror our own version of PGO/crunchy images
- Add pod exec privileges to cluster-healthcheck-serviceaccount
- Add delete patch to remove pingaccess-was healthcheck cronjob from multi-region
- Revert removing alertmanager from the prometheus config
- Add PF transaction logs parsing and indexing
- Fix regional variable for new customer creation
- Installed EBS CSI driver
- Replace deprecated topologyKey
- Add IngressClassName to replace the deprecated annotation
- Fix PingFederate multiline logs parsing
- Exclude dlq pipeline from alerts

_Changes:_

- [X] PDO-2799 Rewrite CloudWatch log tests
- [X] PDO-3165 Refactor offline-enable script to use "dsreplication enable-with-static-topology" subcommand
- [X] PDO-4186 beluga_log is not respecting verbosity levels
- [X] PDO-4224 Properly propagate SSH key when upgrading CSR
- [X] PDO-4240 PF Health Check Tests - Certificates
- [X] PDO-4249 Remove unused networking yaml from PCB
- [X] PDO-4279 Add Pod Disruption Budgets for PA-WAS Engine, PingDelegator
- [X] PDO-4291 PF Health Check Tests - connectivity
- [X] PDO-4312 PA-WAS Health Check Tests - object creation, unauthenticated proxy requests
- [X] PDO-4343 Mirror our own version of PGO/crunchy images
- [X] PDO-4432 Logstash has broken tolerations
- [X] PDO-4439 PF Health Check Tests - object creation, authentication
- [X] PDO-4440 PD Health Check Tests - appintegrations
- [X] PDO-4481 Upgrade kubectl to match K8s version
- [X] PDO-4496 Create new global repo for dashboards
- [X] PDO-4533 Move PCB CI/CD env vars from deploy script to common script
- [X] PDO-4535 Argo CD non-root user changes
- [X] PDO-4543 Create K8s serviceAccount for PA, PD and PF
- [X] PDO-4545 Add delete patch to remove pingaccess-was healthcheck cronjob from multi-region
- [X] PDO-4565 Prometheus: Configure It to Take Metrics from Second Region
- [X] PDO-4566 Logstash: Configure It to Send Logs from Second Region to Primary Region
- [X] PDO-4568 Kibana: Modify Dashboards to Show Second Region Logs and Metrics
- [X] PDO-4569 Remove ES, Kibana and Grafana from second region
- [X] PDO-4574 Pod Reaper pod should re-spin, when env_vars is updated
- [X] PDO-4583 PA Health Check Tests - object creation, unauthenticated proxy requests
- [X] PDO-4610 Retain set value for slack channel alerts
- [X] PDO-4614 Automate pinning the branch for ping-cloud-dashboards in PCB
- [X] PDO-4615 Remove outdated CW logs test methods
- [X] PDO-4618 Default slack notifications using `IS_GA` env var
- [X] PDO-4632 ALERT from the secondary region is shown as an ALERT from the primary region in the email message
- [X] PDO-4636 Remove "PING_CONTAINER_PRIVILEGED" from env_vars
- [X] PDO-4644 Update cluster tools to latest version: NewRelic Java agent v7.11.1
- [X] PDO-4648 Allow release branches to update image names using the kustomize image patch
- [X] PDO-4649 prometheus-0/logstash-elastic-0 pod does not come up upon changing LEGACY_LOGGING or LS_JAVA_OPTS
- [X] PDO-4669 EFS access point dir doesn't remove during PVC removal
- [X] PDO-4671 Refactor elastic-stack manifests
- [X] PDO-4686 Update ping-cloud-base to use the cluster tools from new ECR repo
- [X] PDO-4807 Configure Argo Redis container to run as nonroot
- [X] PDO-4808 Update applications logs location
- [X] PDO-4809 Refactor generate-cluster-state.sh to retain set value for slack channel alerts on upgrade
- [X] PDO-4877 ELK logs for healthcheck pods should be storing for 7 days
- [X] PDO-4918 Missing PF Transaction Log
- [X] PDO-4921 Revert removing alertmanager from the prometheus config
- [X] PDO-4922 Fix regional variable for new customer creation
- [X] PDO-4967 Enable storage class resizing for PGO storageclass
- [X] PDO-4973 REGION_ENV should be defined before using it in ENVIRONMENT_PREFIX in Region env_vars
- [X] PDO-4984 Install EBS CSI driver
- [X] PDO-5015 Disable integration test for PF user authentication healthcheck
- [X] PDO-5029 Remove bypass-acl privilege from PingDataSync account
- [X] PDO-5035 Fix PingDataSync service to send requests to PingDataSync pods
- [X] PDO-5037 Update to replace deprecated topologyKey to topology.kubernetes.io/zone
- [X] PDO-5060 Add IngressClassName to replace the deprecated annotation to support K8s v1.22 onwards
- [X] PDO-5061 Replace healthcheck jobs with deployments
- [X] PDO-5070 Delete patch for healthcheck-pa-was in multi-region removes deployment

### 1.16.2.0

- Healthcheck cronjobs replaced with deployments
- Replace deprecated topologyKey

_Changes:_

- [X] PDO-5014 Replace healthcheck jobs with deployments
- [X] PDO-5037 Update to replace deprecated topologyKey to topology.kubernetes.io/zone

### 1.16.1.0

- Added ENVIRONMENT_TYPE to backup failure notification
- Remove all out-of-the-box IKs from PingFederate base image

_Changes:_

- [X] PDO-4844 Environment Key is missing in Product Backup Failure Alert Message
- [X] PDO-4893 Remove all out-of-the-box IKs from PingFederate base image

### 1.16.0.1

- Force PingAccess engines to get its certificate ID from the engines endpoint instead of HTTP Listener

_Changes:_

- [X] PDO-4804 Force PingAccess engines to get its certificate ID from the engines endpoint instead of HTTP Listener

### 1.16.0.0

- Implemented Radius Proxy as optional installation
- Setup NewRelic Kube Events Integration
- Add newrelic-metadata pod to send metadata to NewRelic
- Add PingAccess and PingAccess-WAS health checks cronjobs
- Update ping-cloud namespace variable
- Add ArgoCD slack notifications secret within SSM and remove from k8s secret
- Added argo-events version 1.7.2
- Enable newrelic-logging for host logs and service cluster-tools pods(kube-system namespace + external-dns)
- Resolve tag _grokparsefailure and log components are missing 
- Add new env_var "DEFAULT_USER_BASE_DN"
- Added event source and webhook for argo-events to enable notification
- LEGACY_LOGGING defaulted to False
- update pingcloud-bom and pingcloud-oauth securityContext with allowPrivilegeEscalation set to false 
- Use camelCase for healthcheck test tags and filenames
- Implemented must-have monitoring/alerting of PGO
- Implement PGO alerting via argo-events
- Added argo-image-updater version v0.12.0
- Fix: Events are not displayed in New Relic for some pods in some namespaces 
- Fix: New relic not reporting accurate pod metrics for some environments
- Switch Delegated Admin to use OAuth Authorization Flow instead of Implicit Flow
- Added ArgoCD slack notifications
- Upgraded Prometheus to v2.39.1

_Changes:_

- [X] PDO-2300 Add ArgoCD slack notifications for better visibility into failure to apply manifests
- [X] PDO-3599 Autoupdate to minor releases of PingOne AS Product Images
- [X] PDO-3785 Add PGO database to CI/CD
- [X] PDO-3791 Create hook script to enable outbound provisioning
- [X] PDO-3823 Add newrelic-metadata pod to send metadata to NewRelic
- [X] PDO-3863 PGO backups
- [X] PDO-4046 Ability to override product initContainer p14c-integration image
- [X] PDO-4089 Notification Framework: Introduce argo-events
- [X] PDO-4096 Failed Cluster Health Job hanging around
- [X] PDO-4104 PA Health Check Tests
- [X] PDO-4110 Switch Delegated Admin to use OAuth Authorization Flow instead of Implicit Flow
- [X] PDO-4117 Go Proxy: Write Manifest to Deploy RadSec Proxy
- [X] PDO-4150 Tag _grokparsefailure and log components are missing
- [X] PDO-4176 Enable desired NewRelic Logging
- [X] PDO-4178 Setup NewRelic Kube Events Integration
- [X] PDO-4207 Add ArgoCD slack notifications secret within SSM and remove from k8s secret
- [X] PDO-4261 Upgrade Kustomize to v4.5.7
- [X] PDO-4274 New relic not reporting accurate pod metrics for Star
- [X] PDO-4281 Update ping-cloud namespace variable
- [X] PDO-4290 Add simple postgres operator (PGO) database
- [X] PDO-4320 Set AllowPrivilegeEscalation to False
- [X] PDO-4326 Implement must-have monitoring/alerting of PGO
- [X] PDO-4327 Implement PGO resource sizing per environment
- [X] PDO-4351 Events are not displayed in New Relic for some pods in some namespaces
- [X] PDO-4397 Add new env_var "DEFAULT_USER_BASE_DN"
- [X] PDO-4391 Notification Framework: alert on backup failure
- [X] PDO-4401 LEGACY_LOGGING mode: Change default from true to false (off) - Leave flag available
- [X] PDO-4432 Logstash has broken tolerations
- [X] PDO-4438 PostgreSQL pods and secrets not deployed
- [X] PDO-4442 Update healthcheck service keys to use consistent format
- [X] PDO-4446 Handle missing SSM parameters
- [X] PDO-4454 Implement Prometheus Alerting
- [X] PDO-4476 Modify PGO feature flag to not require update-cluster script
- [X] PDO-4480 newrelic-license-secret-exporter job not present in newrelic namespace
- [X] PDO-4491 Run Radius as a sidecar container alongside PingFederate engine
- [X] PDO-4492 Enable/disable Radius with environment variable
- [X] PDO-4498 Move nri-kubernetes images to dev ECR within PCB
- [X] PDO-4580 Prometheus Pod is being OOMKilled

### 1.15.1.0

- Fix Logstash broken tolerations

_Changes:_

- [X] PDO-4432 Logstash has broken tolerations

### 1.15.0.1

- Allow multiple Pass-Through-Authentication plugin instances

_Changes:_

- [X] PDO-4558 Allow multiple Pass-Through-Authentication plugin instances

### 1.15.0.0

- Augment ArgoCD's application name with customer name
- Add fix to application name for ArgoCD
- Fix grafana PD topology successful SSOs
- Updated cluster tool sealed-secrets-controller from v0.17.3 to v0.18.0
- Healthcheck cronjobs moved to 'health' namespace
- Update API version in Beluga K8s manifest for EKS v1.22
- Setup EFS as backend for Prometheus storage
- Updated cluster tool cert-manager from v1.5.3 to v1.9.1
- Use generic bootstrap app for p14c and logging
- Improved Grafana dashboards to be more consistent
- Added prometheus-job-exporter deployment to expose command outputs as prometheus metrics
- Added LDAP users count graph
- Add PingFederate health checks cronjob
- Fix Fluent-bit raw logs sending to S3
- Fix secrets sealing

_Changes:_

- [X] PDO-2635 Augment ArgoCD's application name with customer name
- [X] PDO-3271 Updated argocd to v2.4.6
- [X] PDO-3272 Update cluster tool to recommended version: cert-manager v1.9.1
- [X] PDO-3273 Update cluster tool to latest version: sealed-secrets-controller v.0.18.0
- [X] PDO-3524 Create PingOne-Configurator test for CI/CD
- [X] PDO-3575 Cluster tool: force pingcloud-monitoring/newrelic-tags-exporter initContainer to run with allowPrivilegeEscalation: false
- [X] PDO-3918 Move chrome install from run-integration-tests.sh to k8s-deploy-tools image
- [X] PDO-3940 Add timeouts for screen updates in PingOne integration tests
- [X] PDO-3944 Create CI/CD integration test for Health Checks
- [X] PDO-3988 Grafana Successful SSOs Pingfederate Topology dashboard displaying wrong data
- [X] PDO-4002 Unified bootstrap application
- [X] PDO-4036 Fix SigSci to exit properly when terminated
- [X] PDO-4051 Remove PingDirectory config-audit reference from Fluentbit configuration
- [X] PDO-4052 Update to handle NEW_RELIC_LICENSE_KEY environment variable
- [X] PDO-4060 Update versioning for cluster tools in PCB
- [X] PDO-4082 Create a custom sort method to sortBy production release and release candidate
- [X] PDO-4090 Prometheus: Implement EFS to back /data Directory
- [X] PDO-4097 Execute a _start-server.sh.pre script before starting PingDirectory
- [X] PDO-4101 PF Health Check Tests
- [X] PDO-4106 Update profile with X.509 authentication sample
- [X] PDO-4122 Move Health Check Jobs to separate NS
- [X] PDO-4153 Adjust default PingDirectory purge plugin properties
- [X] PDO-4154 Update truststore with signing certificates for X.509 authentication
- [X] PDO-4159 Update API version in Beluga K8s manifest for EKS V1.22
- [X] PDO-4193 Inconsistent performance metrics
- [X] PDO-4205 Create the K8s infrastructure to get active users count for each tenant environment
- [X] PDO-4206 Visualize active users count for each tenant environment data through Grafana dashboards
- [X] PDO-4242 Improve cert-manager ci/cd deployment reliablility
- [X] PDO-4265 Increase memory limits for prometheus pod
- [X] PDO-4268 Fix Fluent-bit raw logs sending to S3
- [X] PDO-4301 Fix secrets sealing

### 1.14.1.0

- Backport logstash tolerations fix

_Changes:_

- [X] PDO-4432 Logstash has broken tolerations

### 1.14.0.1

- Allow multiple Pass-Through-Authentication plugin instances

_Changes:_

- [X] PDO-4547 Allow multiple Pass-Through-Authentication plugin instances

### 1.14.0.0

- Update cluster-tool external-dns from version v0.08.0 to version v.0.11.0
- New image tagging convention for all Ping applications
- SigSci Agent upgraded from v4.24.1 to v4.28.0
- Nginx Ingress Controller upgraded from v1.0.0 to v1.2.0
- Configure PingFederate and PingAccess environments within PingCentral
- Create PingDirectory's Password Credential Validator using PingFederate Admin API
- Grafana upgraded from v6.5.3 to v8.4.5
- Create PingDirectory's LDAP Client Manager using PingFederate Admin API
- Replace Fluentd with Fluent Bit
- Force liveness probe for PingDirectory to use API endpoint /available-or-degraded-state
- Logstash now getting logs from Fluent Bit and working as non-root Deployment
- Cluster tool cluster-autoscaler upgrade from v1.20.0 to v1.21.1
- Fluent Bit now has a FeatureFlag 'LEGACY_LOGGING' to control application logs destination
- Fluent Bit docker image is now pulled from ECR
- Implemented Hot\Warm Tiers for ElasticSearch
- Add "pf-jwt-token-translator-1.1.1.2.jar" to artifact.json file
- Add healthcheck service
- Add cluster-health healthchecks for namespaces, nodes, and statefulsets
- Add logstash parsers for all ping apps
- Add EFS StorageClass. Configure Elasticsearch to use EFS StorageClass
- Add customer-configurable pipeline to logstash
- Fix max-character branch name length for ping-cloud-base
- Convert PingDataSync to a StatefulSet
- Add Pod-Reaper cluster tool
- Implement Kibana-based alerting
- Add logging-bootstrap application
- Fluent Bit now store raw logs on S3
- Remove stunnel from PingDirectory
- Remove skbn as backup mechanism as replaced with aws cli
- Update cronjobs to prevent multiple jobs being scheduled during scaledown

_Changes:_
- [X] PDO-2517 Port of PingFederate pre-config script from bash to python
- [X] PDO-2827 Configure PingFederate and PingAccess environments within PingCentral
- [X] PDO-2894 Use Fluent Bit instead of Fluentd
- [X] PDO-3269 Update cluster tools to latest version: cluster-autoscaler v1.21.1
- [X] PDO-3270 Update cluster tools to latest version: nginx-ingress-controller v1.2.0
- [X] PDO-3274 Update cluster tools to recommended version: external-dns v.11.0
- [X] PDO-3275 Update cluster tools to latest version: Kibana v8.1.3
- [X] PDO-3276 Update cluster tools to latest version: Elasticsearch 8.1.3
- [X] PDO-3277 Update cluster tools to latest version: kube-state-metrics v2.5.0
- [X] PDO-3278 Update cluster tools to latest version: metrics-server v0.6.1
- [X] PDO-3279 Update cluster tools to latest version: Logstash v8.1.3
- [X] PDO-3421 Set ImagePullPolicy for all Ping apps to 'Always'
- [X] PDO-3422 Create script to ensure development ECR public image tag isn't in any production release
- [X] PDO-3428 PA/PF heartbeat exporter doesn't export metric properly after implementing PDO-3207
- [X] PDO-3433 Create PingDirectory's Password Credential Validator using PingFederate Admin API
- [X] PDO-3434 Create PingDirectory's LDAP Client Manager using PingFederate Admin API
- [X] PDO-3446 Upgraded ArgoCD to v2.3.1
- [X] PDO-3522 Create PF admin SSO integration test for CI/CD
- [X] PDO-3548 Set manage-profile tempProfileDirectory argument and force exportldiff files to write to the persistent volume /opt/out directory
- [X] PDO-3571 Added non-admin ArgoCD user with access to restart StatefulSet pods
- [X] PDO-3574 Cluster tool: force bitnami/kubectl initContainer to use its own nonroot user
- [X] PDO-3576 Cluster tool: force busybox initContainer to use its own nonroot user
- [X] PDO-3582 Force liveness probe to use API endpoint /available-or-degraded-state
- [X] PDO-3603 Auto update product tags for production registry in ping-cloud-base
- [X] PDO-3605 Automate release candidate ECR images within in ping-cloud-base
- [X] PDO-3610 Convert PingDataSync to a Statefulset
- [X] PDO-3611 Use 'manage-profile replace-profile' to support root password change
- [X] PDO-3620 Update cluster tools to latest version: Grafana v8.4.5
- [X] PDO-3678 server.publicBaseUrl is not found in Kibana
- [X] PDO-3684 Remove skbn as replaced with aws cli in PD0-3683
- [X] PDO-3716 Elasticsearch: Implement Hot/Warm Tiers
- [X] PDO-3723 Grafana: Upgrade to 8.4.5 risks investigation
- [X] PDO-3743 Automate development ECR images in ping-cloud-base
- [X] PDO-3745 Argocd admin creds in secrets.yaml
- [X] PDO-3753 Configure Fluent Bit to send SIEM logs to logstash
- [X] PDO-3754 Replace current logstash DaemonSet by non-root Deployment
- [X] PDO-3755 Implement FeatureFlags with many outputs for Fluent Bit
- [X] PDO-3773 Encrypt K8s StorageClass (AWS EBS volumes)
- [X] PDO-3780 Connect to external PD server within PingDataSync using LDAPS
- [X] PDO-3783 Recreate the PF Threat Detection Dashboard in P1AS
- [X] PDO-3805 Create & Deploy Health Check service in P1AS
- [X] PDO-3821 Create customer-configurable pipeline in logstash with PQ
- [X] PDO-3830 ES JVM Heapsize too small
- [X] PDO-3840 Update cluster tools to latest version: prometheus to v2.36.1
- [X] PDO-3841 Update cluster tools to latest version: newrelic-infrastructure to 4.5.8
- [X] PDO-3842 Update cluster tools to latest version: newrelic java agent to v6.5.4
- [X] PDO-3843 Update cluster tools to latest version: cloudwatch-agent to v1.247352.0
- [X] PDO-3844 Update cluster tools to latest version: sig-sci agent v4.28.0
- [X] PDO-3851 Implement EFS storage for ElasticSearch
- [X] PDO-3856 PingOne configurator skips is_myping
- [X] PDO-3887 Add config-audit.log and server.out files to PingDirectory tail logs
- [X] PDO-3892 Fluent Bit image is now pulled from ECR
- [X] PDO-3907 Create Cluster Health Tests for Health Checks Pt 1
- [X] PDO-3910 Create a logstash parsers for all ping-app non-SIEM logs
- [X] PDO-3911 Warning message in es-cluster pods logs
- [X] PDO-3912 Few PF Kibana Dashboards and one PD Kibana Dashboard not showing data 
- [X] PDO-3913 Few data views are listed twice in Kibana Discover tab
- [X] PDO-3915 Create Reaper Deployment in PCB
- [X] PDO-3919 Create Cluster Health Tests for Health Checks Pt 2
- [X] PDO-3936 Investigate flaky PingOne integration tests
- [X] PDO-3928 Move script that verifies development images are not in production to tag-release.sh
- [X] PDO-3930 Add "pf-jwt-token-translator-1.1.1.2.jar" to artifact.json file
- [X] PDO-3933 ELK/CloudWatch logging improvements
- [X] PDO-3942 Moved ENVIRONMENT_PREFIX from base env_vars to region env_vars
- [X] PDO-3946 Some of Kibana resources bootstrapping fails in rare cases
- [X] PDO-3956 ELK: there are no log time chart and no window to choose time slot for 'pa-was-system' data view
- [X] PDO-3959 Fix URLs not rendering due to DNS_ZONE envsubst ordering
- [X] PDO-3968 Update logstash image to have all needed plugins
- [X] PDO-3969 Store raw logs on S3
- [X] PDO-3972 Remove stunnel from PingDirectory
- [X] PDO-3974 Implement Kibana Alerting
- [X] PDO-3980 Health Check service is listing wrong envType in a CDE
- [X] PDO-3993 Fix PF Admin API endpoint for integration test
- [X] PDO-4008 Fix max-character branch name for PCB
- [X] PDO-4016 Few data views are listed twice in Kibana Discover tab
- [X] PDO-4040 Add ingress metrics dashboard to Grafana
- [X] PDO-4027 Add logging-bootstrap application
- [X] PDO-4056 Ping Federate - Threat Intel / Detection Dashboard is missing
- [X] PDO-4057 Update all cronjob configs to prevent multiple jobs being scheduled during scaledown
- [X] PDO-4093 Logstash is in crashloop state for chub clusters
- [X] PDO-4098 Newrelic Infrastructure sends data from primary and secondary regions to one NR
- [X] PDO-4108 There are no data on PA-WAS - Response Codes Over Time Kibana Dashboards
- [X] PDO-4121 Cost Savings: New Relic: Globally Update Configuration to use lowDataMode

### 1.13.0

- Deploy PingDataSync into cluster
- Updated the SigSci Agent to run as a non-root user
- Updated  default PingID adapter, PingOne MFA IK, PingOne Risk Management IK
- Force engines to use non-root
- Force admins (PF, PA, PA-WAS, PD) to use non-root
- Update PingFederateConfigurator job to use ansible image
- Run PingDataSync using nonroot user
- Update Pingdatasync secrets volume mount from pingdatasync to pingdirectory
- Update all pingcloud-apps images to support ssh-rsa HostKeyAlgorithm
- Use alpine docker image for enrichment-bootstrap
- Add custom artifacts to PingDataSync to allow custom sync pipes
- Upgrade PF to 11.0.2
- Fix fluentd PD logs parsing configuration
- Fix missing PD logs due to late tail-logs hook call
- Use self-hosted newrelic docker images
- Automate usage of AWS Secrets Manager
- Set min and max CPU properties within run.properties for engine and admin
- Add jetty-runtime.xml to profile-repo
- Move PingCentral AWS RDS MYSQL vars from base/env_vars to region/pingcentral/env_vars
- Turned off pod logs from going into NewRelic
- Fix upgrade-cluster-state script to import new env_vars changes from base
- Fix PingCentral PingOne deployment status and url update

_Changes:_

- [X] BRASS-358 Update Solutions Ansible to continue on error, removed "canUseIntelligenceDataConsent": true from  risk script
- [X] BRASS-359 Add local username attribute to Risk Adapter in PingFederate
- [X] BRASS-367  Pre-configured IdP/SP connections do not match up; don't work OOTB
- [X] BRASS-370  Pre-configured PF Policy incorrect Population ID mapping
- [X] PDO-2092 Allow UDP ports to enable PF RADIUS functionality
- [X] PDO-2233 Change "apiVersion" for CRD resources in ping-cloud-base
- [X] PDO-2350 Add Metric For JVM GC CPU percent in PF
- [X] PDO-2351 Add Metric For JVM Old Gen Collected percent in PF
- [X] PDO-2354 Add Metric For JVM GC CPU percent in PA
- [X] PDO-2356 Add Metric For JVM Old Gen Collected percent in PA
- [X] PDO-2746 Add PingCentral deployment status to PingOne
- [X] PDO-2944 Add urls to metadata pod
- [X] PDO-2951 Deploy PingDataSync into cluster
- [X] PDO-2953 Sync directory from external PD server to P1AS PD server
- [X] PDO-2954 Support PingDataSync logs within CloudWatch
- [X] PDO-2955 Add External PD & P1AS PD certs to PingDataSync TrustStore
- [X] PDO-2995 Update Pingdatasync secrets volume mount from pingdatasync to pingdirectory
- [X] PDO-3017 Upgrade PF to 11.0.1
- [X] PDO-3064 PingAccess hook scripts updated to use the beluga_log method instead of echo
- [X] PDO-3065 PingFederate hook scripts updated to use the beluga_log method instead of echo
- [X] PDO-3103 Force admins (PF, PA, PA-WAS, PD, DA, PC) to use non-root
- [X] PDO-3104 Change PingAccess/PingAccess-WAS beluga_log messages to use beluga_warn or beluga_error
- [X] PDO-3105 Change PingFederate beluga_log messages to use beluga_warn or beluga_error
- [X] PDO-3106 Change PingDirectory beluga_log messages to use beluga_warn or beluga_error
- [X] PDO-3108 Change PingCentral beluga_log messages to use beluga_warn or beluga_error
- [X] PDO-3129 Update json_exporter image version to 0.3.0
- [X] PDO-3142 Run SigSci agent as non-root, update nginx ingress controller security context
- [X] PDO-3146 Change Busybox-based containers in cluster-tools to run as non-root
- [X] PDO-3154 Update Fluentd logs routing
- [X] PDO-3160 Update NGINX ingress controller to use 8080/8443 for the containerPort
- [X] PDO-3163 Change PingFederate Port to 9999 within P14C Integration
- [X] PDO-3167 Update default PingID adapter, PingOne MFA IK, PingOne Risk Management IK
- [X] PDO-3180 Sync directory from P1AS PD server to external PD server
- [X] PDO-3200 Change dev-env.sh script to have better error handling for kubectl apply
- [X] PDO-3207 Force Admins to use non-root
- [X] PDO-3262 Add push rule to repo, README for branch name max length requirement
- [X] PDO-3281 Upgrade PingAccess and PingCentral base images to avoid DOS attack
- [X] PDO-3305 Modify k8s in PCB to run ansible image
- [X] PDO-3307 Update PD status for PingOne
- [X] PDO-3340 PA-WAS pods crashed during 82-upload-csd-s3.sh hook run on test/dev clusters
- [X] PDO-3341 Run PingDataSync using nonroot user
- [X] PDO-3343 Upgrade PingDelegator/DelegatedAdmin to 4.8.0
- [X] PDO-3369 Update p1/newrelic-tags-exporter to run with "ping" user, "identity" group
- [X] PDO-3370 (BugFix) PD running into crashloop after restart with missing PingDirectory.lic file
- [X] PDO-3371 Update all pingcloud-apps images to support ssh-rsa HostKeyAlgorithm
- [X] PDO-3382 Change P1 Deployment to use isMyPing SSM
- [X] PDO-3404 PingDataSync add wait-for-service for external and internal PD instance
- [X] PDO-3406 Set changelog max-age within external PingDirectory server using API and P1AS PingDirectory server using dsconfig
- [X] PDO-3408 Enforce PingDataSync to only deploy within primary region
- [X] PDO-3394 (BugFix) PD status update for P1
- [X] PDO-3411 Move Fluentd CloudWatch config to a separate file
- [X] PDO-3414 Use alpine docker image for enrichment-bootstrap
- [X] PDO-3425 Deploy utils.lib.sh to each product container from one place
- [X] PDO-3449 Add custom artifacts to PingDataSync to allow custom sync pipes
- [X] PDO-3479 Change PA integration test 01-agent-config-test.sh to be idempotent
- [X] PDO-3488 Solutions Ansible entrypoint.sh script null evaluation
- [X] PDO-3501 Consolidate and rename PingDataSync, external PD, and P1AS PD shared variables
- [X] PDO-3502 Update DataSync to use USER_BASE_DN variable
- [X] PDO-3513 (BugFix) Logstash crashlooping due to updated plugin dependencies
- [X] PDO-3518 Fix fluentd PD logs parsing configuration
- [X] PDO-3540 Fix metadata by updating flask to v2.0.3
- [X] PDO-3557 Update PD to 8.3.0.5 to fix JVM crashes
- [X] PDO-3570 Add group identity 9999 for all Ping product applications and avoid escalating privileges
- [X] PDO-3577 Disable external server configuration. Use flag IS_P1AS_TEST_MODE to enable for QA
- [X] PDO-3594 Add a new dsconfig file "45-disable-daily-ldif-export.dsconfig" to turn off on-prem backup
- [X] PDO-3598 Fix missing PD logs
- [X] PDO-3601 Upgrade PF to 11.0.2 to fix OOM issue
- [X] PDO-3606 Backup/restore PingDataSync config/sync-state.ldif file to/from s3
- [X] PDO-3608 Add Secrets Manager objects to Discovery Service
- [X] PDO-3625 Run bootstrap & bom pods in CHUB account
- [X] PDO-3643 NewRelic infrastructure pods pulling from docker instead of ecr
- [X] PDO-3685 Set min and max CPU properties within run.properties for engine and admin
- [X] PDO-3731 Move PingCentral AWS RDS MYSQL vars from base/env_vars to region/pingcentral/env_vars
- [X] PDO-3764 Turn off pod logs from going into NewRelic
- [X] PDO-3771 Fix upgrade-cluster-state script to import new env_vars changes from base
- [X] PDO-3781 Encrypt K8s StorageClass

### 1.12.0

- Added support for SigSci Web Access Firewall (WAF) to Nginx ingress controller
- Updated Nginx ingress controller to version 1.0.0
- Update PF upload artifact script to support Standard IKs
- Updated ArgoCD to version 2.1.6
- Added custom patch to create public ingresses for admin endpoints
- Added multiline log support for PA-WAS
- Added sideband fields to PA logs
- Added regional custom-patches.yaml as an extension point to customize the configuration for a specific region
- Added support for enabling rate-limiting in PA and PA-WAS
- Heartbeat endpoint page template changed
- Removing vestigial code (restore-db-password hook script and dbConfig.jose manipulation) from deployment automation
- Update 20-restart-sequence.sh script to skip rebuild index when no index changes
- Implemented Kubernetes Infrastructure Agent for New Relic
- Fixed showing a few SharedResourceWarnings in ArgoCD UI
- Updated to address Log4Shell vulnerabilities
- Update logstash to 7.16.2
- ElasticSearch image updated to 7.16.2
- Kibana updated to 7.16.2
- Added Open Token Adapter Integration Kit to server profile for PingFederate SSO
- Patched default PF agentless adapter IK
- Upgraded PingFederate to v10.3.5 to resolve security vulnerability SECADV029 and SECBL021
- Turned off pod logs from going into NewRelic

_Changes:_

- [X] PDO-1350 PingAccess proactively remove temp file that causes upgrade to fail
- [X] PDO-1676 Deploy Kubernetes Infrastructure Agent for New Relic
- [X] PDO-2223 Heartbeat endpoint page template changing
- [X] PDO-2368 Refactored IK download script to use artifact-list.json as the single source of truth for all PF IKs
- [X] PDO-2410 PA-WAS: parse multiline logs
- [X] PDO-2432 Update cluster tools to latest version: argocd to v2.1.6
- [X] PDO-2534 SigSci WAF: run the SigSci agent as a sidecar container in the Nginx-ingress-controller pod
- [X] PDO-2895 Update PF upload artifact script to support Standard IKs
- [X] PDO-2921 SigSci WAF: create public ingresses for admin endpoints
- [X] PDO-2928 Add support for enabling rate limiting in PA and PA-WAS
- [X] PDO-2937 Change 'Replica __ {}' metric's names to match the other metric's names template
- [X] PDO-2938 Added regional custom-patches.yaml as an extension point to customize configuration for a specific region
- [X] PDO-2962 Added new PA sideband logs to SIEM Integration
- [X] PDO-2965 Refactor NewRelic APM agents to use Secret located in 'newrelic' namespace
- [X] PDO-2978 Integrate latest New Relic namespace changes in Beluga 1.12
- [X] PDO-2988 Increased metadata pod timeoutSeconds probe to 3 seconds for liveness & readiness
- [X] PDO-2991 SigSci WAF: Update SigSci sidecar resource limit & requests
- [X] PDO-2993 Add "ttlSecondsAfterFinished: 30" to all ping product and Kibana jobs so its pods get reaped upon completion
- [X] PDO-2996 Removing vestigial code (restore-db-password hook script and dbConfig.jose manipulation) from deployment automation
- [X] PDO-3003 Update 20-restart-sequence.sh script to skip rebuild index when no index changes
- [X] PDO-3058 CSD upload file changed from .zip-zip format to .zip
- [X] PDO-3087 Enhance default PingFederate user to support password change and policies by default
- [X] PDO-3092 Force all jobs and cronjobs of Ping products to use non-root
- [X] PDO-3091 Fixed role association on gateway objects created in P14C and PF authentication policy issue for MyPing E2E flow
- [X] PDO-3102 Fix offline replication configuration error when config.ldif has line wrappings
- [X] PDO-3109 Fix code generation script to only use the SSH-RSA host keys for GitHub
- [X] PDO-3110 Make code generation script more resilient to invalid values for IS_GA and IS_MY_PING SSM parameters
- [X] PDO-3115 Remove OOTB Integration Kits for PingFederate
- [X] PDO-3137 Support SSO for multiple PA admin applications per environment
- [X] PDO-3145 Fixed MyPing admin SSO errors caused due to intermittent DNS resolution issues
- [X] PDO-3175 ArgoCD UI shows a few SharedResourceWarnings
- [X] PDO-3179 Argocd failing to deploy newrelic namespace from scratch and shows 3 newrelic resources as out of sync
- [X] PDO-3196 Fix Security Vulnerability CVE-2021-44228 by patching Log4j2 files
- [X] PDO-3218 Updating images for Log4Shell security vulnerability
- [X] PDO-3243 Upgrade New Relic Java Agent to 6.5.2 to address Log4Shell Vulnerability
- [X] PDO-3266 Upgrade Logstash version to 7.16.2 for patches to the log4j2
- [X] PDO-3265 Upgrade Elasticsearch version to 7.16.2 for patches to the log4j2
- [X] PDO-3333 Fix Kibana showing an error 'We encountered an error retrieving search results
- [X] PDO-3352 Add Open Token Adapter Integration Kit to server profile for PingFederate SSO
- [X] PDO-3393 Default Agentless adapter kit deployed has known vulnerabilities
- [X] PDO-3401 Upgrade PingFederate to v10.3.5 to resolve security vulnerability SECADV029 and SECBL021
- [X] PDO-3513 (BugFix) Logstash crashlooping due to updated plugin dependencies
- [X] PDO-3764 Turn off pod logs from going into NewRelic
- [X] PDO-3782 Encrypt K8s StorageClass 

### 1.11.0

- Enabled PingAccess Admin SSO for MyPing customers
- Fixing P14C issuer URL to not have newlines so PA pods do not fail to start up
- Updated p14c-integration image to 1.0.29
- Updated PA to 6.3 to support SSO through P14C (for administrator users) and SSO through PingFederate (for customer users)
- Configured all Ping applications to use the DevOps user/key retrieved through the Discovery service as defaults
- Updated the P14C bootstrap image to query the platform event queue for future updates to MyPing parameters
- Fixed PD Grafana dashboard, 'Replication Backlog' metric with changeable UserBaseDN env var
- Fix PF's run.sh to not map SIGTERM to SIGKILL
- Added the ability to roll out PF/PA/PA-WAS admin and engines separately
- Upgraded newrelic-tags-exporter to version 1.0.5
- Increase memory for FluentD to avoid memory issues in GA deployments
- Fixed error in run.sh when New Relic key isn't provided
- Updated cert-manager from v0.10.1 to v1.5.3
- Added New Relic support for PingCentral
- Decreased log level for argocd
- Updated Pingcentral image version to 1.0.20
- Added support for PingCentral application performance metrics through the NewRelic APM agent
- Support PA database changed from H2 to Apache Derby
- Updated starter configuration to use LE production server for all GA and MyPing customers
- Fixed Pod startup errors due to Prometheus not being able to find jmx_export_config.yaml
- Added PD startupProbe with replication backlog check
- Update cluster tools to version: cluster-autoscaler (1.20.0)
- Update kibana index mappings

_Changes:_

- [X] PDO-1668 Fixing P14C issuer URL to not have newlines so PA pods do not fail to start up
- [X] PDO-2401 create a new hook script "10-download-artifact.sh.post" in the PF image
- [X] PDO-2412 Decrease ArgoCD log level
- [X] PDO-2433 Updated cert-manager from v0.10.1 to v1.5.3
- [X] PDO-2599 Updated starter configuration to use LE production server for all GA and MyPing customers
- [X] PDO-2753 PF Admin SSO Revert script update
- [X] PDO-2758 Enabled PingAccess Admin SSO for MyPing customers
- [X] PDO-2791 Added a script to update server profile code from one version of Beluga to another
- [X] PDO-2810 Added a license pre-hook script that configures the DevOps user/key to use for product licenses
- [X] PDO-2811 Change the default for the DevOps USER/KEY to SSM paths
- [X] PDO-2826 Add replication backlog check to PD readiness check
- [X] PDO-2837 P14C liveness probe hitting wrong URL
- [X] PDO-2846 Updated PA to 6.3
- [X] PDO-2872 Support PA database changed from H2 to Apache Derby
- [X] PDO-2874 Updated the P14C bootstrap image to query the platform event queue for future updates to MyPing parameters
- [X] PDO-2878 Update newrelic-tags-exporter image version to 1.0.5
- [X] PDO-2885 Provide the ability to update PA/PF admin independent of engines
- [X] PDO-2919 Fix PF's run.sh to not map SIGTERM to SIGKILL
- [X] PDO-2935 Increase memory for FluentD to avoid memory issues in GA deployments
- [X] PDO-2936 Error in run.sh when New Relic key isn't provided
- [X] PDO-2941 Add New Relic support for PingCentral
- [X] PDO-2950 Fixed error in PingDirectory's utils.lib.sh for USER_BASE_DN that's 1-level deep, e.g. o=data
- [X] PDO-2958 newrelic-tags-exporter container crashes if 'entitlements' configmap not found
- [X] PDO-2986 Fixed issue with P14C bootstrap image where k8s resource data for SSM params are deleted on param update
- [X] PDO-2989 Add the Beluga version to the cluster-state and profile repos in a version.txt file
- [X] PDO-2990 Pod startup errors due to Prometheus not being able to find jmx_export_config.yaml
- [X] PDO-3027 Update cluster tools to version: cluster-autoscaler (1.20.0)
- [X] PDO-3037 Update PF audit Kibana index mapping
- [X] PDO-3038 Update PA audit Kibana index mapping

### 1.10.0

- Deploy PingCentral in P1AS customer hub clusters
- PA-WAS now verifies each individual Application exists on restarts and upgrades
- PingDirectory health checks are now performed via HTTPS
- Update a few supporting cluster tools to their latest versions
- Beluga maintained container images with built in hook scripts
- Server profiles are now seeded into a separate repository for partner access
- Add Elasticsearch wait init container to kibana manifest
- Updated cluster-autoscalar memory request/limit to 512 MB
- Fixed PD Grafana dashboard, 'Replication Backlog' metric
- Updated p14c-integration image to 1.0.28
- Upgraded PingDirectory to version 8.3.0.0
- Upgraded PingFederate to version 10.3.1
- Modify all P1AS apps to use user_id:group_id => 9031:9999
- Remove NATIVE_S3_PING as a supported JGroups discovery protocol for PF clustering
- Enabling access to the PingCentral Admin UI via PingAccess WAS
- Move DA Configuration to offline mode within PD
- Update images to pull from ECR

_Changes:_

- [X] PDO-700 Deploy PingCentral in P1AS customer hub clusters
- [X] PDO-1739 Migrate to Beluga container images
- [X] PDO-2208 Change "apiVersion" for ingress resources in ping-cloud-base
- [X] PDO-2386 Improve upgrade of PA-WAS by making idempotent
- [X] PDO-2387 Remove the nginx annotation service-upstream from all ingresses
- [X] PDO-2430 Update cluster tools to latest version: cluster-autoscaler (1.17.4)
- [X] PDO-2434 Update cluster tools to latest version: sealed-secrets-controller (0.16.0)
- [X] PDO-2435 Update cluster tools to latest version: external-dns (0.8.0)
- [X] PDO-2445 Logstash date parsing errors
- [X] PDO-2462 Update cluster tools to latest version: Kibana (7.13.2)
- [X] PDO-2463 Update cluster tools to latest version: Elasticsearch (7.13.2)
- [X] PDO-2465 Update cluster tools to latest version: metrics-server (v0.5.0)
- [X] PDO-2468 Update PD healthchecks to use the availability servlet
- [X] PDO-2571 Add P1AS Branding to PF Admin Console
- [X] PDO-2623 Separate the server profiles into its own repository for partner enablement
- [X] PDO-2624 Restore and backup PingCentral encryption key file from S3
- [X] PDO-2638 Update cluster tools to latest version: Logstash (7.13.2)
- [X] PDO-2676 Update the push-cluster-state.sh script to push seed code into the new profile-repo
- [X] PDO-2686 Provide a wrapper script in the profile-repo to update profiles from one version to another
- [X] PDO-2687 Update update-cluster-state-wrapper.sh to seed initial customer-hub code into the CSR
- [X] PDO-2700 Fix inconsistency in "newrelic-tags-exporter" init container between PA/PF/PD
- [X] PDO-2705 NR agent could crash if config file contains empty tag values (Config Syntax Error))
- [X] PDO-2708 Fix image tag kustomization in the CSR for P1AS app images
- [X] PDO-2709 Decommission the JFrog pull cache and use public ECR for all images
- [X] PDO-2713 Change PingCentral application password
- [X] PDO-2715 Move DA Configuration to offline mode within PD
- [X] PDO-2717 Adapt the Discovery service to retrieve the PingCentral database details from SSM
- [X] PDO-2718 Allow MyPing image tags to be Kustomizable
- [X] PDO-2721 Logstash index template didn't create during deployment
- [X] PDO-2728 Update p14c-integration docker images in ping-cloud-base
- [X] PDO-2739 Press more app-specific concerns into the images instead of exposing them in the profile-repo
- [X] PDO-2741 Update cluster-autoscalar memory request/limit to 512 MB
- [X] PDO-2740 No data on PD Grafana dashboard, 'Replication Backlog' metric
- [X] PDO-2754 Remove NATIVE_S3_PING as a supported JGroups discovery protocol for PF clustering
- [X] PDO-2763 Wrong way of retrieving NR account_type tag data
- [X] PDO-2764 Upgrade PF to version 10.3.1
- [X] PDO-2779 Implement CloudWatch for PingCentral Log Files
- [X] PDO-2788 Upgraded PingDirectory to version 8.3.0.0
- [X] PDO-2789 Force PingCentral to communicate to RDS using SSL connection
- [X] PDO-2794 Enabling access to the PingCentral Admin UI via PingAccess WAS
- [X] PDO-2806 Ensure that profile changes are being applied on a restart
- [X] PDO-2807 Add a public NLB in the customer-hub VPC for the metadata service
- [X] PDO-2814 Modify all P1AS apps to use user_id:group_id => 9031:9999
- [X] PDO-2830 Set PingCentral k8s deployment strategy to Recreate
- [X] PDO-2832 Move PingCentral v1.8.0 from edge to a stable tag
- [X] PDO-2849 Reuse environment variables in the env_vars file in the CSR as much as possible
- [X] PDO-2851 Cleanup PingCentral application.properties file
- [X] PDO-2869 Change PingFederate v10.3.1-edge image tag to a stable version
- [X] PDO-2916 Enable/or disable PingCentral development endpoints using an environment variable

### 1.9.3

- Fix a PingDirectory crash caused by the offline-enable hook script after a restart
- Remove PingFederate-P14C-Init container from secondary region
- Updated p14c-integration image to 1.0.24
- Update prometheus-json-exporter image to 1.0.3
- Upgraded PingFederate to version 10.2.4
- Capture additional logs from rebuild-index within PD
- Fixed hook script issue with updated collect-support-data tool

_Changes:_

- [X] PDO-2631 Upgrade PF to version 10.2.4
- [X] PDO-2637 PingDirectroy crashloops on restart in the offline-enable hook script
- [x] PDO-2661 Remove pingfederate-p14c-init container in secondary
- [X] PDO-2668 Update p14c-integration docker images in ping-cloud-base to v1.0.23
- [X] PDO-2688 Use latest prometheus-json-exporter image
- [X] PDO-2689 Capture additional logs from rebuild-index within PD
- [X] PDO-2690 Updating the PD and PF 82-upload-csd-s3.sh hook scripts to work with the updated collect-support-data tool
- [X] PDO-2723 Update p14c-integration docker images in ping-cloud-base to v1.0.24

### 1.9.2

- P14c-oauth and p14c-bom controllers now restart when pingone api is inaccessible
- Preserve PingDirectory descriptor.json across CSR updates
- Added entitled-app: "true" label to PingFederate Admin and PingAccess Admin
- Updated p14c-integration image to 1.0.22
- Updated p14c-bootstrap image to 1.0.9
- Fixed external access to the PingFederate admin API
- Removing pf-referenceid-adapter-2.0.1.jar if it is found on the filesystem
- DA now creates its own Identity Mapper within PD
- Fixed issue with DA IDP Adapter Grant Mapping to handle Persistent Grant Extended Attributes
- Updated PF heap settings to match 1.7.2 values

_Changes:_

- [X] PDO-2203 Add liveness probe to p14c-oauth and p14c-bom controllers
- [X] PDO-2285 Narrow Kube watch pods for Bom Controller
- [X] PDO-2431 Update to use ingress-nginx/controller:v0.46.0
- [X] PDO-2539 Preserve PingDirectory descriptor.json across CSR updates
- [X] PDO-2578 Updated p14c-integration image to 1.0.20 and p14c-bootstrap image to 1.0.9
- [X] PDO-2579 Update to use skbn v1.0.1
- [X] PDO-2607 Fix external access to the PingFederate admin API
- [X] PDO-2609 Removing pf-referenceid-adapter-2.0.1.jar if it is found on the filesystem
- [X] PDO-2633 DA now creates its own Identity Mapper within PD
- [X] PDO-2639 Update p14c-integration docker images in ping-cloud-base to v1.0.21
- [X] PDO-2641 Fixed issue with DA IDP Adapter Grant Mapping to handle Persistent Grant Extended Attributes
- [X] PDO-2645 Fix PF product Heap Variable Settings to return to 1.7 values
- [X] PDO-2665 My Ping Trial deployment failure RCA - Workforce solution - p14c-e2e-reliability267-271

### 1.9.1

- Fixed Elasticsearch cluster not able to select a primary
- Removed duplicate PingDelegator logs from CloudWatch
- Reduced log output on curl calls
- Fixed the problem where PingFederate fails to crashloop pods when artifact-list.json contains improper json
- Added the pingfederate-p14c-init container to PingFederate engine nodes so that integration kits are deployed on engines
- Updated fluentd to aggregate multiline log messages

_Changes:_

- [X] PDO-2243 Remove duplicate messages from PingDelegator's access.log
- [X] PDO-2308 Update PD liveness check to use an absolute path
- [X] PDO-2335 PingFederate fails to crashloop pods when artifact-list.json contains improper json
- [X] PDO-2399 Multi-line logs not displaying in CW properly
- [X] PDO-2413 Remove curl progress output from logs
- [X] PDO-2439 Elasticsearch log level to warn
- [X] PDO-2490 Allow auto-expansion of all volumes (Elastic logging, PD, and PA/PA-WAS/PF admins)
- [X] PDO-2507 NS 2 - Missing integration kit file in the node on CIAM environment

### 1.9.0

- Add PingDelegator 4.4.1 as a new application in P1AS
- Upgraded PingFederate to version 10.2
- Upgraded PingDirectory to version 8.2.0.4
- Option to enable Delegated Admin
- Provisioned Workforce/Customer 360 Plugins (PF Trial)
- Added a metadata service to display Ping Cloud metadata component versions
- Added PingFederate NewRelic APM Agent

_Changes:_

- [X] PDO-1133 Multi-Region Kubernetes DNS
- [X] PDO-1606 DA - Create k8s ingress resource
- [X] PDO-1607 DA - Create k8s service
- [X] PDO-1608 DA - Create k8s Deployment
- [X] PDO-1609 DA - Create a liveness and readiness probe
- [X] PDO-1610 DA - Create PingDelegator environment variables configmap
- [X] PDO-1612 DA - Integrate PingDelegator logs with AWS CloudWatch
- [X] PDO-1615 DA - customizations to Ping Cloud templates
- [X] PDO-1621 Add a metadata service to display Ping Cloud metadata component versions
- [X] PDO-1638 Upgrade PF to 10.2
- [X] PDO-1639 Beluga k8s stack fails to build with customize version >= 3.9
- [X] PDO-1669 Provision Workforce/Customer 360 Plugins (PF Trial)
- [X] PDO-1704 DA - Integrate PingDelegator with PingFederate
- [X] PDO-1721 MyPing -> Ping Cloud bootstrap secrets and configuration
- [X] PDO-1758 Create the OAuth client services controller Deployment object
- [X] PDO-1771 Add access control to ECR registries in CSG AWS account
- [X] PDO-1773 ECR: ensure that untagged images get periodically cleaned up
- [X] PDO-1775 Change the JSON for the metadata service to future proof it for additional metadata
- [X] PDO-1777 DA - Move docker image to JFrog registry
- [X] PDO-1788 DA - Integrate PingDelegator with PingDirectory
- [X] PDO-1801 Image tag customization broke in v1.7
- [X] PDO-1802 Performance degradation of git-ops-command.sh due to PDO-1578
- [X] PDO-2072 Provide patch for increasing header-size on public nginx for Kerberos
- [X] PDO-2098 Change the image repo for the Ping Cloud monitoring image
- [X] PDO-2122 Remove waiting on pingdirectory-0 to speed up PF bootstrap on rolling updates
- [X] PDO-2124 ALL_MIN_SECRETS_FOUND not set when running update cluster script
- [X] PDO-2130 DA: Create ConfigMap and Secrets to hold common variables for DA, PF, and PD
- [X] PDO-2133 Add custom-patch-sample for schedule edits of corncobs into custom-patch-sample.yaml
- [X] PDO-2134 Setup NR Agent for PF
- [X] PDO-2135 Setup tags for PF APM NR
- [X] PDO-2175 Public URL for variable PD_HTTP_PUBLIC_HOSTNAME is not set in PingCloud
- [X] PDO-2225 p14c-bootstrap k8s: add IRSA to new Ping service account
- [X] PDO-2234 Remove MyPing controllers from secondary regions
- [X] PDO-2236 Remove Daily encrypted exports run in PD - redundant as backups are already taken to S3
- [X] PDO-2252 Rebuild the indexes before starting/restarting the server
- [X] PDO-2253 DA: Integrate administrator as the default Delegated Admin
- [X] PDO-2254 ArgoCD: enable auto-pruning to prevent OutOfSync issues on update
- [X] PDO-2261 Decrease PD cpu in medium/large to support new relic pods
- [X] PDO-2279 Create PodDisruptionBudget for PF Runtime
- [X] PDO-2280 Create PodDisruptionBudget for PA Runtime
- [X] PDO-2281 Create PodDisruptionBudget for PD
- [X] PDO-2296 Custom secrets printed in startup log
- [X] PDO-2306 Long-running PD pods being OOMKilled when there is no user activity
- [X] PDO-2314 Set data backups for PA/PF to run at the half-hour mark
- [X] PDO-2316 Metadata pod crashing due to resource pressure
- [X] PDO-2319 Upgrade script replaces custom-resources and custom-patches
- [X] PDO-2320 Run PD periodic backup processes at different times to mitigate OOMKills
- [X] PDO-2322 Add sealed-secrets annotation to argocd-secret
- [X] PDO-2323 Hook script failed to get pod metadata when pod suffix is double digit
- [X] PDO-2336 Adjust pod sizes. Pods being OOMKilled in dev environments
- [X] PDO-2338 PD throws LDAP exception when PF initially deploys
- [X] PDO-2371 Upgrade DA and PD images
- [X] PDO-2391 Fix ACI causing UI warning in DA
- [X] PDO-2395 Enable DA Sessions
- [X] PDO-2415 Update to turn acl flag on for native s3
- [X] PDO-2474 PF-admin is crashing at start-up after running environment upgrade

### 1.8.3

- Increase PD pod resources to account for ad-hoc java processes

- [X] PDO-2178 PingDirectory Pods - backup processes cause pod restarts

### 1.8.2

- Fixed PingFederate issue where LDAP stores added after initial bootstrap were getting removed on restart.

- [X] PDO-2125 Data loss in PF on pod rolling

### 1.8.1

- Fixed PingFederate to not allow back-channel access after revoking persistent session
- Decreased CPU requests and limits of the PingDirectory stunnel sidecar container
- Fixed the update-cluster-state-wrapper.sh script to preserve customer size

_Changes:_

- [X] PDO-1712 PingFederate back-channel access available even after revoking persistent session
- [X] PDO-2068 Evaluate pod sizing for small deployment sizing
- [X] PDO-2086 RESET_TO_DEFAULT flag of update CSR script not preserving customer size
- [X] PDO-2094 PingDirectory backup for large backup files fails

### 1.8.0

- Upgraded PingFederate to 10.1.4
- Standardized CSD export naming convention to an easily retrievable name
- Added periodic CSD log collection for PingAccess WAS admin and engines
- Added Grafana dashboards for PingFederate and PingAccess
- Changed the default environment size to x-small for dev and test environments to reduce costs
- Replaced FluxCD with ArgoCD as the continuous delivery tool
- Enabled IAM Roles for Kubernetes Service Accounts (IRSA) to pare down pod permissions

_Changes:_

- [X] PDO-1030 Expose the relevant Operation Data from PingFederate through a JMX exporter
- [X] PDO-1031 Expose the relevant Operation Data from PingAccess through a protocol that can be consumed by Prometheus
- [X] PDO-1032 Import PingFederate Operation Data to Prometheus
- [X] PDO-1033 Import PingAccess Operation Data to Prometheus
- [X] PDO-1388 Standardize CSD Export naming convention to an easily retrievable name
- [X] PDO-1390 Collect CSD data for pingaccess-was and pingaccess-was-admin
- [X] PDO-1533 Count relevant Operational Data for PingFederate from existing logs
- [X] PDO-1536 Count relevant Operational Data for PingAccess from existing logs
- [X] PDO-1539 Deploy a very small deployment size as the default for dev/test
- [X] PDO-1564 Add ArgoCD as the continuous delivery tool in Ping Cloud environments
- [X] PDO-1569 Enable IRSA for K8s Pods to use AWS IAM role
- [X] PDO-1570 Configure PA-WAS to proxy to the ArgoCD UI
- [X] PDO-1578 Allow more granular upgrades of ping applications
- [X] PDO-1664 Fix edge-case errors with push-clouster-state.sh
- [X] PDO-1671 PingCloud deployments of Stage CDE needs to be the same size as Prod
- [X] PDO-1722 Update PD k8s configs to use PD labels only in production
- [X] PDO-1747 Set up a pull cache for ArgoCD images from docker.io in the JFrog mirror
- [X] PDO-1770 Update SIEM logstash/elasticsearch images from using JFrog to ECR
- [X] PDO-1799 Upgrade PF to 10.1.4
- [X] PDO-1812 improper shutdowns of PF not cleaned up
- [X] PDO-1821 Upload json_exporter Docker image to ECR
- [X] PDO-2025 PA engine crash looping due to excessive public key creation
- [X] PDO-2042 Change the staging directory for restore to not use the tmp file system
- [X] PDO-2058 PD fails when changing out USER_BASE_DN
- [X] PDO-2061 PA post-start failure does not stop the server as intended
- [X] PDO-2066 Update script not handling files with spaces in the name

### 1.7.2

- Decreased stunnel cpu resources
- Fixed the seal.sh script, which was broken when the IRSA environment variable was made regional in v1.7.1

_Changes:_

- [X] PDO-2068 Evaluate pod sizing for small deployment sizing
- [X] PDO-2067 seal.sh script broken

### 1.7.1

- Added a script to update the cluster-state repo from one release to another
- Provide extension points within k8s-configs for PS/GSO customizations

_Changes:_

- [X] PDO-1397 Add a script to update the cluster-state repo from one release to another
- [X] PDO-1663 Templatize the env_vars files generated by the generate-cluster-state.sh script
- [X] PDO-1746 Provide extension points within k8s-configs for PS/GSO customizations

### 1.7.0

- GSA images can now be pulled via the JFrog registry instead of DockerHub to prevent throttling limits
- Added PA log collection for SIEM
- Automated deployment of PA and PF customer license keys
- Updated PA-WAS, PF, and PA
- Reduced logging noise

_Changes:_

- [X] PDO-1357 Rename PD CSD Exports to an easily retrievable name
- [X] PDO-1362 PA log Collection for SIEM
- [X] PDO-1376 Rewrite SIEM filters for PD to work with log files
- [X] PDO-1384 Ensure PD pods run on PD nodes
- [X] PDO-1385 Always import PA admin config query key-pair on start/restart
- [X] PDO-1389 Remove unused secrets for Kibana, Grafana, and Prometheus from ping-cloud-base
- [X] PDO-1421 Automate deploying the customer license key for PingFederate
- [X] PDO-1425 Automate deploying the customer license key for PingAccess
- [X] PDO-1426 Automate configuring PingAccess customer templates
- [X] PDO-1469 Reduce config duplication on multi-region deployments
- [X] PDO-1481 Update cluster-autoscaler image url and decrease log level
- [X] PDO-1482 Decrease cloudwatch-agent log level
- [X] PDO-1487 Fix 00-ditstructure and 20-plugin-purge-sessions.dsconfig mismatch
- [X] PDO-1493 Fix GLOBAL_TENANT_DOMAIN regardless of how customer is named in the cluster-state-repo
- [X] PDO-1497 Upgrade PF to 10.1.2
- [X] PDO-1498 Upgrade PA to 6.1.3
- [X] PDO-1503 Upgrade PA-WAS to 6.13
- [X] PDO-1515 Remove similar log messages from Ping product health checks
- [X] PDO-1519 Move secrets to base directory since all regions must share secrets for an environment
- [X] PDO-1522 Replace missing memory limits on PD pods and adjust MAX_HEAP_SIZE defaults
- [X] PDO-1543 Fix CLUSTER_BUCKET_NAME is not the same between regions for multi-region environments
- [X] PDO-1567 Pull GSA images from Frog registry
- [X] PDO-1571 Update flux so it only has read-only access to the repo
- [X] PDO-1572 Add PA upgrade logs to its own log stream
- [X] PDO-1617 Fixed issue with LDAP users on PD being orphaned
- [X] PDO-1622 Update flux to not cache docker images
- [X] PDO-1631 Move all docker.io registry images to JFrog to avoid rate limit error
- [X] PDO-1648 Set ARTIFACT_REPO_URL variable to be region specific

### 1.6.1

- Updated PingDirectory image to 8.1.0.2 so replication initialization does not lock down a new server
- Ignoring PingDirectory topology descriptor file in single-region environments
- Fixed ability to update PingDirectory license after initial launch

_Changes:_

- [X] PDO-1393: update PingDirectory image to 8.1.0.2 so replication initialization does not lock down a new server
- [X] PDO-1494: Ignore PingDirectory topology descriptor file in single-region environments
- [X] PDO-1514: Unable to update PingDirectory license after initial launch

### 1.6.0

- Added multi-region support of PD, PF, and PA
- Added periodic CSD uploads for PF admin, PA admin/engine
- Leveraged topology-aware volume provisioning for all StatefulSets
- Added Web Application Firewall to PF/PA admin UIs, Kibana, Grafana and Prometheus
- Added SIEM for PingFederate

_Changes:_

- [X] PDO-685 - Deploy PD in each region
- [X] PDO-686 - Deploy PF in primary region
- [X] PDO-687 - Deploy PF in secondary region
- [X] PDO-688 - Deploy PA in primary region
- [X] PDO-690 - Deploy PA in secondary region
- [X] PDO-884 - Update generate-cluster-state.sh script to support multiple clusters
- [X] PDO-885 - Update push-cluster-state.sh script to support multiple clusters
- [X] PDO-886 - Update flux configuration to point to the correct directories within the cluster-state-repo for each cluster
- [X] PDO-999 - Discovery Service - update generate-cluster-state script to remove variables with cde prefix
- [X] PDO-1202 - PingFederate admin now creates and upload CSD regularly
- [X] PDO-1203 - PingAccess admin/runtime now creates and upload CSD regularly
- [X] PDO-1227 - Leveraged topology-aware volume provisioning for all StatefulSets
- [X] PDO-1228 - Added soft affinity to PA/PF Engines for multi-region
- [X] PDO-1242 - Enabled cluster communication between peered VPCs
- [X] PDO-1252 - Added log level to elastic-stack application
- [X] PDO-1259 - Removed PingDataConsole
- [X] PDO-1262 - Added custom log function, beluga_log, to server profile hooks
- [X] PDO-1270 - Verify config changes can occur with backups and not be deleted from S3 for PF and PA admins
- [X] PDO-1273 - PingDirectory - update offline-enable to use cluster communication over peered-VPC vs. NLB
- [X] PDO-1277 - PA - update hook scripts of admin and runtimes for runtimes in secondary cluster to join admin using keypair
- [X] PDO-1276 - Update pingcommon initContainer for PD/PF/PA/PA-WAS
- [X] PDO-1304 - Removed PA-WAS from secondary region
- [X] PDO-1309 - Update wait-for-service initContainer to check multiple ports for PD/PF/PA/PA-WAS
- [X] PDO-1311 - Fixed issue with warnings about env_vars file during container startup
- [X] PDO-1317 - Increased Cert Manager resources to handle multi-region deployments
- [X] PDO-1321 - Force PingDirectory in secondary region to wait for PingDirectory in primary region
- [X] PDO-1331 - Created a customized hook script to support PA/PA-WAS admin and runtime liveness probe
- [X] PDO-1332 - Fixed issue with PF pods becoming unresponsive during endurance
- [X] PDO-1334 - Added Web Application Firewall in for PF/PA Admin UIs
- [X] PDO-1335 - Added Web Application Firewall in for Kibana, Grafana, Prometheus
- [X] PDO-1345 - Update PingCloud to use custom log stash images
- [X] PDO-1346 - Fixed SIEM for PF
- [X] PDO-1349 - Removed Calico
- [X] PDO-1352 - Increased PA Admin requests/limits to enable successful PA version upgrades for dev/test cde environments
- [X] PDO-1383 - Added logic to verify provided PD hostname before deploying to multi-region
- [X] PDO-1386 - Fixed issue with SIEM logging incorrectly and being sent to CloudWatch
- [X] PDO-1391 - Added missing index-pattern for Logstash in ELK
- [X] PDO-1396 - Added DNS_PING with MULTI_PING to the groups stack for added reliability
- [X] PDO-1412 - Removed the logic in server profile hook that explicitly copies config archive to PF engine drop-in-deployer directory
- [X] PDO-1432 - Fixed incompatibility between PA Admin SSO and PA-WAS
- [X] PDO-1435 - Fixed Logstash errors in pods
- [X] PDO-1440 - Fixed Logstash errors in Kibana
- [X] PDO-1453 - Added logic to Fluentd container to only log at error level
- [X] PDO-1467 - Fixed multi-region global url into ingress service so multi-region failover works
- [X] PDO-1468 - Fixed PD periodic backups from failing
- [X] PDO-1474 - PD - fixed replace-profile errors when transitioning from single to multi-cluster
- [X] PDO-1480 - After initial launch, scaling up a PD server does not initialize replication data

### 1.5.0

- Added Pingaccess-WAS deployment
- Enabled SIEM for PingDirectory
- Created Discovery Service for variable discovery across regions
- Setup use of SKBN to replace AWS specific implementation

_Changes:_

- [X] PDO-366 - Create K8s Deployment for internal PingAccess
- [X] PDO-458 - Fixed PF pods not getting configuration from admin when spun up
- [X] PDO-748 - Protect PF Admin UI
- [X] PDO-749 - Configure P14C to generate tokens that PA WAS can consume
- [X] PDO-753 - Set up PA Internal to allow P14C to act as Token Provider for PingCloud Web/API Security
- [X] PDO-754 - Store P14C Token Provider Creds in PingCloud within the CDE
- [X] PDO-757 - Protect PA Customer Admin UI
- [X] PDO-812 - Protect Prometheus Endpoint
- [X] PDO-839 - Discovery Service (Environment Variables for Backup & Log AWS S3 Buckets)
- [X] PDO-857 - Edit PD Restore script to use pre/post external initialization of replication in place of scale down/up used currently
- [X] PDO-870 - Creating Kibana dashboards
- [X] PDO-944 - PD - Use skbn to restore and backup data/log from k8s to s3 bucket
- [X] PDO-955 - Fixed dashboards in Grafana broken with EKS upgrade
- [X] PDO-959 - Update ping-cloud-base to support EKS v1.16
- [X] PDO-961 - PF- Use skbn to download artifact/archive and upload csd logs
- [X] PDO-962 - Migration to logstash (instead fluentd)
- [X] PDO-963 - Porting fluentd configs to logstash format
- [X] PDO-965 - Setting up PD log collection
- [X] PDO-966 - Setting up logstash filters
- [X] PDO-968 - Setting up logstash outputs (including client-side SIEM env)
- [X] PDO-969 - Creating enrichment service
- [X] PDO-973 - Creating Bootstrap engine
- [X] PDO-975 - Protect Grafana Endpoint
- [X] PDO-976 - Expose PD REST API
- [X] PDO-977 - Expose PD SCIM API
- [X] PDO-987 - PA - Use skbn to download and restore backup
- [X] PDO-1001 - Default PF Admins to Audit Only
- [X] PDO-1002 - Configure PA WAS hardware and scaling requirements for multi-region
- [X] PDO-1014 - Host skbn executables on AWS object storage service (S3 bucket)
- [X] PDO-1022 - PF - Recover to a specified recovery point
- [X] PDO-1037 - Fixed default PF thread count incorrect
- [X] PDO-1045 - Elastic stack improvements
- [X] PDO-1086 - Fixed PingFederate tried to start before a temporary instance had fully shut down.
- [X] PDO-1087 - Synchronize supported features for PA and PF backup/restore
- [X] PDO-1137 - Fixed Sealed-Secrets-Controller fails to generate xls cert resulting in inability to seal/unseal secrets stored for our deployment in New Launch environments
- [X] PDO-1188 - Fixed logging in 10-configuration-overrides to provide better diagnostic information.
- [X] PDO-1193 - 1.5: Update PD Docker Images to specified docker image and product version
- [X] PDO-1194 - 1.5: Update PF Docker Images to specified docker image and product version
- [X] PDO-1195 - 1.5: Update PA Docker Images to specified docker image and product version
- [X] PDO-1197 - 1.5: PA upgrade with existing data is busted due to Docker image update
- [X] PDO-1213 - Update critical dependencies for the v1.5 release
- [X] PDO-1223 - Logging improvements to deployment automation hook scripts
- [X] PDO-1251 - external-dns application log level
- [X] PDO-1293 - Fixed PF Pods not responding to requests
- [X] PDO-1303 - Fixed PF_LOG_LEVEL should be set to INFO by default and be overridable
- [X] PDO-1318 - Fixed probe/liveness timeouts
- [X] PDO-1320 - Fixed PF/PA audit log rotation
- [X] PDO-1322 - Fixed PF pods become unresponsive during endurance

### 1.4.3

- Resolved an issue prevent access to server profiles

_Changes:_

- [X] PDO-1150 - Need variable replacement added for new secrets.yaml files so need .tmpl extension added in ping-cloud-base

### 1.4.2

- Fixed ingresses to force HTTP traffic to be redirected to HTTPS
- Fixed a data loss issue in PingFederate admin that was caused by switching it to use a persistent disk
- Fixed a typo in PingDirectory's BACKENDS_TO_BACKUP environment variable
- Fixed the base DN to point to the right backend in PingDirectory's purge-sessions script

_Changes:_

- [X] PDO-845 - PingDirectory purge-sessions script set up to use incorrect DN for the backend to be purged
- [X] PDO-1119 - Data loss caused by switching PingFederate admin to use a persistent disk
- [X] PDO-1123 - Fix typo in PingDirectory BACKENDS_TO_BACKUP environment variable
- [X] PDO-1124 - HTTP ingress traffic should be redirected to use HTTPS

### 1.4.1

- Changed PingAccess 'podManagementPolicy' to 'OrderedReady' to support zero-downtime update of engines
- Fixed encryption errors encountered while restoring PingDirectory user and operational data from backups
- Disabled automatic key renewal on the Bitnami sealed-secrets controller

_Changes:_

- [X] PDO-1083 - PingAccess podManagementPolicy 'Parallel' tears down all engines at the same time
- [X] PDO-1089 - Attempt to restore backups made after changing encryption-password for PingDirectory fails
- [X] PDO-1092 - CI/CD cluster's capacity reduced by half due to PingFederate limit changes in base
- [X] PDO-1095 - Bitnami sealed-secrets controller rotates keys every 30 days

### 1.4.0

- Updated Container Insights to silo each product log file into log streams
- Allow pre-launch configuration to be customized for PingFederate
- Added support for in-place upgrade of the PingFederate admin server
- Added support for PingAccess artifact service
- Changed the PingAccess file and database passwords from its default value
- Downsized PingDirectory persistent volume to reduce cost
- Updated PingDirectory deployment automation to remove its persistent volume on scale-down to reduce cost

_Changes:_

- [X] PDO-334 - Deploy PingAccess kits, plugins & jars
- [X] PDO-335 - Update PingAccess kits, plugins & jars
- [X] PDO-337 - Upgrade PingFederate to a later version
- [X] PDO-504 - Allow pre-launch configuration to be customized for PingFederate
- [X] PDO-585 - Change the default PingAccess file and database passwords
- [X] PDO-679 - Expose prometheus outside of EKS
- [X] PDO-790 - PingDirectory sizing changes to reduce cost
- [X] PDO-822 - Clean-up PVCs on PingDirectory pod scale-down
- [X] PDO-842 - Configure Container Insights to capture more logs for all Ping Products
- [X] PDO-988 - Need to find workaround for PingDirectory failing to join topology due to duplicate entries
- [X] PDO-1005 - PingDirectory SDK DEBUG logging should be disabled by default
- [X] PDO-1007 - PingFederate utils method using wrong password when making admin API requests
- [X] PDO-1008 - Add limits to PingDirectory's stats-exporter container
- [X] PDO-1009 - PingFederate log4j2.xml org.sourceid using invalid variable
- [X] PDO-1041 - Set limits on every Beluga deployment/statefulset spec
- [X] PDO-1053 - Inconsistent PingAccess Artifacts between admin and engine pods
- [X] PDO-1054 - Change imagePullPolicy to "ifNotPresent" across the board
- [X] PDO-1058 - PingDirectory 3rd server cannot join the cluster topology
- [X] PDO-1060 - Fix PingFederate liveness probe to better represent server state
- [X] PDO-1061 - Allow NLB(s) to support cross-zone load balancing
- [X] PDO-1067 - PingFederate admin cannot establish a connection to PingDirectory
- [X] PDO-1068 - Set the artifact list to download the useful and common plugins for PingFederate
- [X] PDO-1069 - Default PingFederate runtime pod sizing

### 1.3.2

- Fixed PingDirectory deployment automation to replace the server profile fully so that environment variable changes
  are always honored
- Fixed PingAccess deployment automation such that the Backup CronJob does not crash the admin server

_Changes:_

- [X] PDO-928 - Workaround for DS-41964: replace-profile does not honor environment variable changes
- [X] PDO-930 - Output managed-profile logs to the container console on failure
- [X] PDO-949 - PingAccess backup CronJob does not wait for admin to be ready and crashes admin

### 1.3.1

- Fixed PingAccess engine flapping due to HPA and Flux interfering with each other
- Fixed PingAccess deployment automation to enable verbose logging only if VERBOSE is true
- Fixed PingDirectory backup to include PingFederate data under the o=appintegrations backend
- Fixed PingDirectory rolling update to preserve the server's MAX_HEAP_SIZE setting
- Fixed PingFederate restore job to not fail if there are too many backup files

_Changes:_

- [X] PDO-845 - Purge sessions script purging wrong backend
- [X] PDO-846 - Setting minReplicas 1 and maxReplicas 2 for PingAccess HPA causes second PA pod to cycle
- [X] PDO-847 - PF Admin default bootstraping if S3 contains too many files
- [X] PDO-862 - PA Pod horizontal auto-scale cycling too quickly under load
- [X] PDO-900 - PA automation - enable verbose logging only if VERBOSE is true
- [X] PDO-903 - PD backup does not include PF data under o=appintegrations
- [X] PDO-916 - PD deployment automation: running replace-profile drops JVM heap space down to 384MB

### 1.3.0

- Added support for PingAccess deployment automation, including initial deployment of a cluster, auto-scaling,
  auto-healing of failed admin and engine instances, encrypted backup of the master key for disaster recovery upon
  instance and AZ failure
- Added the ability to capture and upload PingFederate CSD archives to S3, if using AWS
- Updated PingDirectory from 8.0.0.0 to 8.0.0.1
- Updated PingFederate from 10.0.0 to 10.0.1
- Updated cluster-autoscaler from v1.13.9 to v1.14.4
- Added the ability to define service dependencies between Ping application using the WAIT_FOR_SERVICES environment
  variable

_Changes:_

- [X] PDO-143 - Recover from a disaster that occurs within an existing PingAccess deployment
- [X] PDO-256 - Create K8s clustered deployment for PingAccess Admin and Engines
- [X] PDO-322 - PA Clustered engine Auto-Scaling Descriptor
- [X] PDO-376 - PA Periodically backup config
- [X] PDO-521 - Master Key Delivery Interface for PA
- [X] PDO-529 - Disable replication for all base DNs on pre-stop
- [X] PDO-533 - Switch to PA 6.0.1 version
- [X] PDO-630 - PingAccess - creating and updating engine certificates
- [X] PDO-631 - Look into removing PingAccess server profile wait functions
- [X] PDO-629 - PingAccess is forced to restart upon uploading engines keypair certificate
- [X] PDO-653 - Extract PingAccess heap sizes into environment variables
- [X] PDO-701 - Configure PingAccess Engines to use serviceAccount RBAC
- [X] PDO-723 - WAIT_FOR_SERVICES to define service dependencies
- [X] PDO-737 - PF CSD logs persistence to S3 bucket
- [X] PDO-743 - PingAccess crashes upon new deployment
- [X] PDO-750 - Switch to PF 10.0.1 version
- [X] PDO-751 - Switch to PD 8.0.0.1 version
- [X] PDO-752 - PD Pod Image Upgrade Broken Due To Incompatible JVM Settings
- [X] PDO-771 - Wonky issue where pingdirectory-0 pod somehow lost its password file on upgrade from v1.2.0 to v1.3.0
- [X] PDO-776 - PingAccess 81-import-initial-configuration script isn't checking to see if keypair already exists
- [X] PDO-792 - PingAccess upload configuration to S3 after successful deployment
- [X] PDO-793 - Manual PD Backup fails
- [X] PDO-794 - Redact log passwords for PingFederate and PingAccess
- [X] PDO-795 - PW change to PA Causes Issues with Kubernetes
- [X] PDO-797 - Periodic Upload of PF CSD Logs Failing
- [X] PDO-810 - Cherry Pick from Master - Update PF deployment automation to upload data.zip to s3 upon start/restart
- [X] PDO-816 - Upgrade cluster-autoscaler version to 1.14.x
- [X] PDO-817 - Add pod anti-affinities for each ES pod to be deployed to a separate node and potentially separate AZ
- [X] PDO-810 - Wait for the admin API to be ready before uploading data to s3
- [X] PDO-820 - Force pod restart on PA API call failure

### 1.2.0

- Added support for P14C pass-through authentication so customer IAM admins can login to PingFederate using their CAP
  credentials
- Reconfigured PingFederate admin authentication to use LDAPS
- Enabled replication for o=platformconfig and o=appintegrations, where PingFederate administrative data is stored

_Changes:_

- [X] PDO-624 Reconfigure PF admin authentication to use LDAPS
- [X] PDO-648 Write a pre-parse PingDirectory plugin for P14C pass-through authentication
- [X] PDO-649 Enable replication for ou=admins,o=platformconfig on ping-cloud-base
- [X] PDO-650 Add dsconfig to PD server profile for the pre-parse and pass-through auth plugins
- [X] PDO-678 The appintegrations backend is not being replicated

### 1.1.1

- Added the ability to override heap size of PingDirectory via MAX_HEAP_SIZE environment variable
- Added the ability to set TLS versions and ciphers for the LDAPS endpoint via environment variables
- Added the ability in PingDirectory to automatically enable/initialize replication after baseDN is updated
- Added the ability to specify the user data backup file to restore from S3
- Added the ability to specify the PingDirectory server from which to back up user data to S3
- Fixed PingDirectory extensions to default to public if something incorrect is entered
- Fixed PingFederate administrative configuration to import on all PingDirectory servers instead of first server only
- Fixed sealed secrets to not overwrite secrets if they already exist

_Changes:_

- [X] PDO-561 PF administrative configuration (e.g. admin users) were only being imported on the first PD server
- [X] PDO-564 PD extensions default to public even if something incorrect is entered
- [X] PDO-568 PD updates to USER_BASE_DN should automatically enable/initialize replication for that baseDN
- [X] PDO-578 Sealed secrets do not overwrite secrets if they already exist
- [X] PDO-611 Unable to set TLS version and ciphers for the LDAPS endpoint via environment variables

### 1.1.0

- Added a Kubernetes CronJob for periodic backup of PingDirectory user data to S3, if using AWS
- Added a Kubernetes Job for manual backups of PingDirectory user data to S3, if using AWS
- Added a Kubernetes Job for restoring PingDirectory user data from S3, if using AWS
- Added support for installing and updating PingDirectory extensions, similar to PingFederate kits
- Separated the PingFederate admin configuration from customer end users in the PingDirectory DIT
- Organized the cluster state repo into branches for different environments instead of a single master branch with
  directories for each environment

_Changes:_

- [X] PDO-305 PD extensions are installed correctly
- [X] PDO-306 PD extensions are updated correctly
- [X] PDO-311 Able to change all user passwords for each tenant environment
- [X] PDO-312 Able to install product licenses for each tenant environment
- [X] PDO-314 Provide method and documentation to encrypt secrets at rest
- [X] PDO-434 Add support for periodic backup of PD user data to S3
- [X] PDO-435 Add a Job for restoring PD user data from S3
- [X] PDO-436 Add a Job for backing PD user data to S3 for ClickOps
- [X] PDO-470 Separate PD/PF profile config from data
- [X] PDO-514 Provide a push-cluster-state.sh script that organizes cluster state repo into branches

### 1.0.0

- Added support for PingDirectory deployment automation, including initial setup of a replication topology, scaling,
  auto-healing of failed instances, backup/restore for disaster recovery upon instance and AZ failure and periodic
  collection of CSD archives
- Added support for PingFederate deployment automation, including initial deployment of a cluster, auto-scaling,
  auto-healing of failed admin and engine instances, encrypted backup of the master key for disaster recovery upon
  instance and AZ failure
