# Changelog

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

# Changelog

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