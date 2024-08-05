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
- [X] PDO-7522 Fix autoscaling resource version to use v2
- [X] PDO-7528 Making Graviton as default for NON-GA environment, fix GA consistency across envs
- [X] PDO-7530 Implement permanent reduction of OS resources in 1.19.1
- [X] PDO-7548 Add 'source cluster' identifier to graphs legend for Volume Autoscaler dashboard 
- [X] PDO-7606 Updated Fluent Bit resource to successfully flush records when under minimal load 
- [X] PDO-7570 Logstash: Update config to include K8s resource labels
- [X] PDO-7703 Logstash: Revisit PodDisruptionBudget
- [X] PDO-7725:Implementing PDO-7558 Karpenter Cost saving changes
- [X] PDO-7742 NewRelic: Optimize Metric Collection by Removing Unnecessary Data Points
- [X] PDO-7759 Increase NR interval to 30s
- [X] PDO-7768 Add customer-defined name to external IdP
- [X] PDO-7788 customer-p1-connection job suspension prevents ArgoCD app healthy status
- [X] PDO-7805 Remove application/node logs from CloudWatch
- [X] PDO-7806 added additional labels in logstash config
