# Changelog

### 1.13.0

_Changes:_

- [X] PDO-3064 PingAccess hook scripts updated to use the beluga_log method instead of echo

### 1.12.0

- Added custom patch to create public ingresses for admin endpoints
- Heartbeat endpoint page template changed
- Add support for enabling rate limiting in PA and PA-WAS
- Added regional custom-patches.yaml as an extension point to customize configuration for a specific region 
- Updated ingress to v1.0.0 and added the SigSci agent sidecar container to the public Nginx-ingress-controller pod
- Add multiline log support for PA-WAS
- Implemented Kubernetes Infrastructure Agent for New Relic
- Updated argocd to latest release: v2.1.6
- Add sideband fields to PA logs
- Force StatefulSets (PF-admin, PA-admin, PA-was-admin, PD) to use non-root user

_Changes:_

- [X] PDO-1350 PingAccess proactively remove temp file that causes upgrade to fail
- [X] PDO-2223 Heartbeat endpoint page template changing
- [X] PDO-1676 Deploy Kubernetes Infrastructure Agent for New Relic
- [X] PDO-2410 PA-WAS: parse multiline logs
- [X] PDO-2432 Update cluster tools to latest version: argocd to v2.1.6
- [X] PDO-2534 SigSci WAF: run the SigSci agent as a sidecar container in the Nginx-ingress-controller pod
- [X] PDO-2921 SigSci WAF: create public ingresses for admin endpoints
- [X] PDO-2928 Add support for enabling rate limiting in PA and PA-WAS
- [X] PDO-2938 Added regional custom-patches.yaml as an extension point to customize configuration for a specific region
- [X] PDO-2962 Added new PA sideband logs to SIEM Integration
- [X] PDO-2965 Refactor NewRelic APM agents to use Secret located in 'newrelic' namespace
- [X] PDO-2988 Increased metadata pod timeoutSeconds probe to 3 seconds for liveness & readiness
- [X] PDO-2991 SigSci WAF: Update SigSci sidecar resource limit & requests
- [X] PDO-3058 CSD upload file changed from .zip-zip format to .zip
- [X] PDO-3092 Force all jobs and cronjobs of Ping products to use non-root
- [X] PDO-3091 Fixed role association on gateway objects created in P14C and PF authentication policy issue for MyPing E2E flow
- [X] PDO-3102 Fix offline replication configuration error when config.ldif has line wrappings
- [X] PDO-3103 Force StatefulSets (PF-admin, PA-admin, PA-was-admin, PD) to use non-root user
- [X] PDO-3109 Fix code generation script to only use the SSH-RSA host keys for GitHub
- [X] PDO-3110 Make code generation script more resilient to invalid values for IS_GA and IS_MY_PING SSM parameters 
- [X] PDO-3137 Support SSO for multiple PA admin applications per environment

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
