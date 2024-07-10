# Changelog

### 2.0.0

- Update seal-secret-values.py script to seal with namespace only. Update secret structure
- Update version regexes from v*.*.*.* to v*.*.*
- Update csd upload tests for products to support removal of ad-hoc PD jobs
- Update HPAs to prevent flapping on short bursting CPU loads
- Commenting out existing PD refs, now pulling in p1as-pingdirectory helm chart
- Grafana fix PGO dashboard
- Support customer bringing their own certificate for their external server and adding it to PingDataSync truststore
- Making Graviton as default for NON-GA environment, fix GA consistency across envs
- Updated Newrelic agent to latest version
- Refactor update-profile-wrapper code to support new variables for microservice profile mirrors.

_Changes:_

- [X] PDO-7428 Update seal-secret-values.py to seal with namespace only. Update secret structure
- [X] PDO-5729 Update version regexes
- [X] PDO-5888 Implement p1as-pingdirectory pipeline deploy stage
- [X] PDO-5900 Add p1as-pingdirectory code-gen directory to PCB
- [X] PDO-6573 Support customer bringing their own certificate for their external server and adding it to PingDataSync truststore
- [X] PDO-6744 Refactor update and generate scripts to pull from microservice repo mirrors
- [X] PDO-6877 Update HPAs to prevent flapping on short bursting CPU loads
- [X] PDO-7527 Grafana: Update PGO dashboards to be compatible with the current PGO version
- [X] PDO-7608 Making Graviton as default for NON-GA environment, fix GA consistency across envs
- [X] PDO-7248 NewRelic: Upgrade APM agent to latest version

### 1.19.1.0

_Changes:_

- [X] PDO-5864 Add job and secret for connection between customer PingOne and shared PingOne
- [X] PDO-6332 Remove all thread count limits from PingDirectory
- [X] PDO-6661 Remove Cronjob / Job for PingDataSync
- [X] PDO-7238 Remove KMS Init Container from PingDirectory
- [X] PDO-7348 PF transaction log parsing improvements
- [X] PDO-7394 Remove Grafana dashboards from secondary region
- [X] PDO-7434 Update Logstash HPA
- [X] PDO-7456 Upgrade Karpenter to 0.37.0
- [X] PDO-7461 Updated Prometheus CPU and memory limits
- [X] PDO-7528 Making Graviton as default for NON-GA environment, fix GA consistency across envs
- [X] PDO-7530 Implement permanent reduction of OS resources in 1.19.1
- [X] PDO-7548 Add 'source cluster' identifier to graphs legend for Volume Autoscaler dashboard 
- [X] PDO-7606 Updated Fluent Bit resource to successfully flush records when under minimal load 
