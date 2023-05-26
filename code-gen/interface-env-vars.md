| Variable                         | Purpose                                             | Default (if not present)                                                |
| -------------------------------- | --------------------------------------------------- | ----------------------------------------------------------------------- |
| ACCOUNT_BASE_PATH                | The account's SSM base path                         | The SSM path: /pcpt/config/k8s-config/accounts/                         |
|                                  |                                                     |
| ARGOCD_SLACK_TOKEN_SSM_PATH      | SSM path to secret token for ArgoCD slack           | The SSM path:                                                           |
|                                  | notifications                                       | ssm://pcpt/argocd/notification/slack/access_token                       |
|                                  |                                                     |
| ARGOCD_CDE_ROLE_SSM_TEMPLATE     | SSM template path for the ArgoCD Chub -> CDE roles  | The SSM template (to be rendered in python script) path:                |
|                                  |                                                     | '/pcpt/config/k8s-config/accounts/{env}/argo/role/arn'                  |
| ARGOCD_CDE_URL_SSM_TEMPLATE      | SSM template path for the ArgoCD Chub -> CDE URLs   | The SSM template (to be rendered in python script) path:                |
|                                  |                                                     | '/pcpt/config/k8s-config/accounts/{env}/cluster/url'                    |
| ARGOCD_BOOTSTRAP_ENABLED         | Feature flag to enabled/disable ArgoCD Chub -> CDE  | The string "true"                                                       |
|                                  | bootstrapping itself                                |
|                                  |                                                     |
| ARGOCD_ENVIRONMENTS              | All environments that Argo should manage            | The env var ${ENVIRONMENTS}                                             |
|                                  |                                                     |
| ARTIFACT_REPO_URL                | The URL for plugins (e.g. PF kits, PD extensions).  | The string "unused".                                                    |
|                                  | If not provided, the Ping stack will be             |
|                                  | provisioned without plugins. This URL must always   |
|                                  | have an s3 scheme, e.g.                             |
|                                  | s3://customer-repo-bucket-name.                     |
|                                  |                                                     |
| BACKUP_URL                       | The URL of the backup location. If provided, data   | The string "unused".                                                    |
|                                  | backups are periodically captured and sent to this  |
|                                  | URL. For AWS S3 buckets, it must be an S3 URL,      |
|                                  | e.g. s3://backups.                                  |
|                                  |                                                     |
| CLUSTER_STATE_REPO_URL           | The URL of the cluster-state repo.                  | https://github.com/pingidentity/ping-cloud-base                         |
|                                  |                                                     |
| ENVIRONMENTS                     | The environments the customer is entitled to. This  | dev test stage prod customer-hub                                        |
|                                  | will be a subset of SUPPORTED_ENVIRONMENT_TYPES     |
|                                  |                                                     |
| EXTERNAL_INGRESS_ENABLED         | List of ping apps(pingaccess,pingaccess-was,        | No defaults                                                             |
|                                  | pingdirectory,pingdelegator,pingfederate) for       |
|                                  | which you can enable external ingress(the values    |
|                                  | are ping app names )                                |
|                                  | Examplelist:(pingaccess pingdirectory pingfederate) |
|                                  |                                                     |
| GLOBAL_TENANT_DOMAIN             | Region-independent URL used for DNS failover/       | Replaces the first segment of                                           |
|                                  | routing.                                            | the TENANT_DOMAIN value with the                                        |
|                                  |                                                     | string "global". For example, it will                                   |
|                                  |                                                     | default to "global.poc.ping.com" for                                    |
|                                  |                                                     | tenant domain "us1.poc.ping.cloud".                                     |
|                                  |                                                     |
| IRSA_ARGOCD_ANNOTATION_KEY_VALUE | The IRSA annotation to add to ArgoCD resources      | eks.amazonaws.com/role-arn: arn:aws:iam::SOME_ACCOUNT_ID:role/SOME_ROLE |
|                                  |                                                     |
| IS_BELUGA_ENV                    | An optional flag that may be provided to indicate   | false. Only intended for Beluga                                         |
|                                  | that the cluster state is being generated for       | developers.                                                             |
|                                  | testing during Beluga development. If set to true,  |
|                                  | the cluster name is assumed to be the tenant name   |
|                                  | and the tenant domain assumed to be the same        |
|                                  | across all 4 CDEs. On the other hand, in PCPT, the  |
|                                  | cluster name for the CDEs are hardcoded to dev,     |
|                                  | test, stage and prod. The domain names for the      |
|                                  | CDEs are derived from the TENANT_DOMAIN variable    |
|                                  | as documented above. This flag exists because the   |
|                                  | Beluga developers only have access to one domain    |
|                                  | and hosted zone in their Ping IAM account role.     |
|                                  |                                                     |
| IS_GA                            | A flag indicating whether or not this is a GA       | The SSM path: /pcpt/stage/is-ga                                         |
|                                  | customer.                                           |
|                                  |                                                     |
| IS_MULTI_CLUSTER                 | Flag indicating whether or not this is a            | false                                                                   |
|                                  | multi-cluster deployment.                           |
|                                  |                                                     |
| IS_MY_PING                       | A flag indicating whether or not this is a MyPing   | The SSM path: /pcpt/orch-api/is-myping                                  |
|                                  | customer.                                           |
|                                  |                                                     |
| K8S_GIT_BRANCH                   | The Git branch within the above Git URL.            | The git branch where this script                                        |
|                                  |                                                     | exists, i.e. CI_COMMIT_REF_NAME                                         |
|                                  |                                                     |
| K8S_GIT_URL                      | The Git URL of the Kubernetes base manifest files.  | https://github.com/pingidentity/ping-cloud-base                         |
|                                  |                                                     |
| LOG_ARCHIVE_URL                  | The URL of the log archives. If provided, logs are  | The string "unused".                                                    |
|                                  | periodically captured and sent to this URL. For     |
|                                  | AWS S3 buckets, it must be an S3 URL, e.g.          |
|                                  | s3://logs.                                          |
|                                  |                                                     |
| PD_MONITOR_BUCKET_URL            | The URL of the monitor,ldif exports and csd-log     |
|                                  | archives.If provided, logs are periodically         | The string "unused"                                                     |
|                                  | captured and sent to this URL. Used only for        |
|                                  | PingDirectory at the moment                         |
|                                  |                                                     |
| MYSQL_PASSWORD                   | The DBA password of the PingCentral MySQL RDS       | The SSM path:                                                           |
|                                  | database.                                           | ssm://aws/reference/secretsmanager//pcpt/ping-central/dbserver#password |
|                                  |                                                     |
| MYSQL_SERVICE_HOST               | The hostname of the MySQL database server.          | pingcentraldb.${PRIMARY_TENANT_DOMAIN}                                  |
|                                  |                                                     |
| MYSQL_USER                       | The DBA user of the PingCentral MySQL RDS           | The SSM path:                                                           |
|                                  | database.                                           | ssm://aws/reference/secretsmanager//pcpt/ping-central/dbserver#username |
|                                  |                                                     |
| NEW_RELIC_LICENSE_KEY            | The key of NewRelic APM Agent used to send data to  | The SSM path: ssm://pcpt/sre/new-relic/java-agent-license-key           |
|                                  | NewRelic account.                                   |
|                                  |                                                     |
| NOTIFICATION_ENABLED             | Flag indicating if alerts should be sent to the     | False                                                                   |
|                                  | endpoint configured in the argo-events              |
|                                  |                                                     |
| NLB_EIP_PATH_PREFIX              | The SSM path prefix which stores comma separated    | The string "unused".                                                    |
|                                  | AWS Elastic IP allocation IDs that exist in the     |
|                                  | CDE account of the Ping Cloud customers.            |
|                                  | The environment type is appended to the SSM key     |
|                                  | path before the value is retrieved from the         |
|                                  | AWS SSM endpoint. The EIP allocation IDs must be    |
|                                  | added as an annotation to the corresponding K8s     |
|                                  | service for the AWS NLB to use the AWS Elastic IP.  |
|                                  |                                                     |
| CUSTOMER_SSO_SSM_PATH_PREFIX     | The prefix of the SSM path that contains PingOne    | /pcpt/customer/sso                                                      |
|                                  | state data required for the P14C/P1AS integration.  |
|                                  |                                                     |
| ORCH_API_SSM_PATH_PREFIX         | The prefix of the SSM path that contains MyPing     | /pcpt/orch-api                                                          |
|                                  | state data required for the P14C/P1AS integration.  |
|                                  |                                                     |
| PF_PROVISIONING_ENABLED          | Feature Flag - Indicates if the outbound            | False                                                                   |
|                                  | provisioning feature for PingFederate is enabled    |
|                                  | !! Not yet available for multi-region customers !!  |
|                                  |                                                     |
| PGO_BUCKET_URI_SUFFIX            | The SSM path suffix to the pgo backups bucket uri   | The SSM path: /pgo-bucket/uri                                           |
|                                  |                                                     |
| PING_ARTIFACT_REPO_URL           | This environment variable can be used to overwrite  | https://ping-artifacts.s3-us-west-2.amazonaws.com                       |
|                                  | the default endpoint for public plugins. This URL   |
|                                  | must use an https scheme as shown by the default    |
|                                  | value.                                              |
|                                  |                                                     |
| PING_IDENTITY_DEVOPS_KEY         | The key to the devops user.                         | The SSM path:                                                           |
|                                  |                                                     | ssm://pcpt/devops-license/key                                           |
|                                  |                                                     |
| PING_IDENTITY_DEVOPS_USER        | A user with license to run Ping Software.           | The SSM path:                                                           |
|                                  |                                                     | ssm://pcpt/devops-license/user                                          |
|                                  |                                                     |
| PLATFORM_EVENT_QUEUE_NAME        | The name of the queue that may be used to notify    | v2_platform_event_queue.fifo                                            |
|                                  | PingCloud applications of platform events. This     |
|                                  | is currently only used if the orchestrator for      |
|                                  | PingCloud environments is MyPing.                   |
|                                  |                                                     |
| PRIMARY_REGION                   | In multi-cluster environments, the primary region.  | Same as REGION.                                                         |
|                                  | Only used if IS_MULTI_CLUSTER is true.              |
|                                  |                                                     |
| PRIMARY_TENANT_DOMAIN            | In multi-cluster environments, the primary domain.  | Same as TENANT_DOMAIN.                                                  |
|                                  | Only used if IS_MULTI_CLUSTER is true.              |
|                                  |                                                     |
| PROM_NOTIFICATION_ENABLED        | Flag indicating if PGO alerts should be sent to     | False                                                                   |
|                                  | the endpoint configured in the argo-events          |
|                                  |                                                     |
| PROM_SLACK_CHANNEL               | The Slack channel name for PGO argo-events to send  | CDE environment: p1as-application-oncall                                |
|                                  | notification.                                       |
|                                  |                                                     |
| RADIUS_PROXY_ENABLED             | Feature Flag - Indicates if the radius proxy        | False                                                                   |
|                                  | feature for PingFederate engines is enabled         |
|                                  |                                                     |
| REGION                           | The region where the tenant environment is          | us-west-2                                                               |
|                                  | deployed. For PCPT, this is a required parameter    |
|                                  | to Container Insights, an AWS-specific logging      |
|                                  | and monitoring solution.                            |
|                                  |                                                     |
| REGION_NICK_NAME                 | An optional nick name for the region. For example,  | Same as REGION.                                                         |
|                                  | this variable may be set to a unique name in        |
|                                  | multi-cluster deployments which live in the same    |
|                                  | region. The nick name will be used as the name of   |
|                                  | the region-specific code directory in the cluster   |
|                                  | state repo.                                         |
|                                  |                                                     |
| SECONDARY_TENANT_DOMAINS         | A comma-separated list of tenant domain suffixes    | No default.                                                             |
|                                  | of secondary regions in multi-region environments,  |
|                                  | e.g. "xxx.eu1.ping.cloud,xxx.au1.ping.cloud".       |
|                                  | The primary tenant domain suffix must not be in     |
|                                  | the list. Only used if IS_MULTI_CLUSTER is true.    |
|                                  |                                                     |
| SERVER_PROFILE_URL               | The URL for the server-profiles repo.               | URL of CLUSTER_STATE_REPO_URL with the                                  |
|                                  |                                                     | name profile-repo, if not provided.                                     |
|                                  |                                                     |
| SERVICE_SSM_PATH_PREFIX          | The prefix of the SSM path that contains service    | /pcpt/service                                                           |
|                                  | state data required for the cluster.                |
|                                  |                                                     |
| SLACK_CHANNEL                    | The Slack channel name for argo-events to send      | CDE environment: p1as-application-oncall                                |
|                                  | notification.                                       |
|                                  |                                                     |
| NON_GA_SLACK_CHANNEL             | The Slack channel name for argo-events to send      | CDE environment: nowhere                                                |
|                                  | notification in case of IS_GA set to 'false' to     | Dev environment: nowhere                                                |
|                                  | reduce amount of unnecessary notifications sent     |
|                                  | to on-call channel. Overrides SLACK_CHANNEL         |
|                                  | variable value if IS_GA=false. By default, set      |
|                                  | to non-existent channel name to prevent flooding.   |
|                                  |                                                     |
| SIZE                             | Size of the environment, which pertains to the      | x-small                                                                 |
|                                  | number of user identities. Legal values are         |
|                                  | x-small, small, medium or large.                    |
|                                  |                                                     |
| SSH_ID_KEY_FILE                  | The file containing the private-key (in PEM         | No default                                                              |
|                                  | format) used by the CD tool and Ping containers to  |
|                                  | access the cluster state and config repos,          |
|                                  | respectively. If not provided, a new key-pair       |
|                                  | will be generated by the script. If provided, the   |
|                                  | SSH_ID_PUB_FILE must also be provided and           |
|                                  | correspond to this private key.                     |
|                                  |                                                     |
| SSH_ID_PUB_FILE                  | The file containing the public-key (in PEM format)  | No default                                                              |
|                                  | used by the CD tool and Ping containers to access   |
|                                  | the cluster state and config repos, respectively.   |
|                                  | If not provided, a new key-pair will be generated   |
|                                  | by the script. If provided, the SSH_ID_KEY_FILE     |
|                                  | must also be provided and correspond to this        |
|                                  | public key.                                         |
|                                  |                                                     |
| SUPPORTED_ENVIRONMENT_TYPES      | The environment types that will be supported for    | dev test stage prod customer-hub                                        |
|                                  | the customer                                        |
|                                  |                                                     |
| TARGET_DIR                       | The directory where the manifest files will be      | /tmp/sandbox                                                            |
|                                  | generated. If the target directory exists, it will  |
|                                  | be deleted.                                         |
|                                  |                                                     |
| TENANT_DOMAIN                    | The tenant's domain suffix that's common to all     | ci-cd.ping-oasis.com                                                    |
|                                  | CDEs e.g. k8s-icecream.com. The tenant domain in    |
|                                  | each CDE is assumed to have the CDE name as the     |
|                                  | prefix, followed by a hyphen. For example, for the  |
|                                  | above suffix, the tenant domain for stage is        |
|                                  | assumed to be stage-k8s-icecream.com and a hosted   |
|                                  | zone assumed to exist on Route53 for that domain.   |
|                                  |                                                     |
| TENANT_NAME                      | The name of the tenant, e.g. k8s-icecream. If       | First segment of the TENANT_DOMAIN                                      |
|                                  | provided, this value will be used for the cluster   | value. E.g. it will default to "ci-cd"                                  |
|                                  | name and must have the correct case (e.g. ci-cd     | for tenant domain "ci-cd.ping-oasis.com"                                |
|                                  | vs. CI-CD).                                         |
|                                  |                                                     |
|                                  |                                                     |
| UPGRADE                          | Indicates generate-cluster-state.sh is running as   | The string "false"                                                      |
|                                  | an upgrade not an initial generation                |
|                                  |                                                     |
