# Enviornment Variables

See the [full list](https://github.com/pingidentity/pingidentity-devops-getting-started/tree/master/docs/docker-images/pingbase) of all the environment variables within the Docker images. You can override these variables at the Kubernetes layer per product.

The following charts show the additional environment variables that may be defined at the Kubernetes layer per release.

### v1.3.1

## PingDirectory

| Name               | Default Value            | Description  | Comments |
| ------------------ | ------------------------ | ------------ | -------- |
| BACKENDS_TO_BACKUP | userRoot;appintegrations | A semicolon-separated list of backend IDs for which periodic backups must be taken. | |
| LEAVE_DISK_AFTER_SERVER_DELETE | false | A flag indicating that the server's disk must be left around after it has been deleted. | |

### v1.3.0

## PingAccess

| Name          | Default Value | Description  | Comments |
| ------------- | ------------- | ------------ | -------- |
| API_RETRY_LIMIT | 10 | The maximum number of times that requests to the PingAccess Admin API are retried upon failure. | |
| API_TIMEOUT_WAIT | 5 | The response timeout in seconds for requests to the PingAccess Admin API. | |
| BACKUP_FILE_NAME | No default | Data backup file name within S3. | When running the click ops manual job restore, you can specify desired data backup file to restore from S3. e.g. pa-data-MM-DD-YYYY.HH.MM.SS.zip  |
| CONFIG_QUERY_KP_VALID_DAYS | 365 | Valid days for the PingAccess Config Query Listener KeyPair. | |
| VERBOSE | true | Triggers verbose messages in scripts using the set -x option. | |


### v1.1.1

## PingDirectory

| Name          | Default Value | Description  | Comments |
| ------------- | ------------- | ------------ | -------- |
| DISABLE_ALL_OLDER_USER_BASE_DN | true | Disables replication on all previous user base DNs. | |
| K8S_ACME_CERT_SECRET_NAME      | acme-tls-cert | Kubernetes secret object name for the ACME certificate obtained from Let's Encrypt. | |
| BACKUP_FILE_NAME | No default | User data backup file name within S3. | When running the click ops manual job restore, you can specify desired user data backup file to restore from S3. e.g. data-MM-DD-YYYY.HH.MM.SS.zip  |
| BACKUP_RESTORE_POD | pingdirectory-0 | PingDirectory server within the topology to backup/restore user data in S3. | When running the click ops manual jobs backup or restore, you can choose server within the topology to backup/restore. |


### v1.1.0

## PingDirectory

| Name          | Default Value | Description  | Comments |
| ------------- | ------------- | ------------ | -------- |
| BACKUP_URL | No default | The URL of the backup location. If provided, data backups are periodically captured and sent to this URL. | For AWS S3 buckets, it must be an S3 URL, e.g. s3://backups. |
| BACKUP_RESTORE_POD | pingdirectory-0 | Default PingDirectory server name to which to restore user data backup. | If pingdirectory-0 is not available, then you can specify another PingDirectory server to which to restore user data backup. |


### v1.0.0

## PingFederate

| Name          | Default Value | Description  | Comments |
| ------------- | ------------- | ------------ | -------- |
| BACKUP_URL | No default | The URL of the backup location. If provided, data backups are periodically captured and sent to this URL. | For AWS S3 buckets, it must be an S3 URL, e.g. s3://backups. Also, the PingFederate admin server writes the master key to this location, and the PingFederate engines read it from there. If not set, the PingFederate servers will fail to start. |
| API_RETRY_LIMIT | 10 | The maximum number of times that requests to the PingFederate Admin API are retried upon failure. | |
| API_TIMEOUT_WAIT | 5 | The response timeout in seconds for requests to the PingFederate Admin API. | |
| VERBOSE | true | Triggers verbose messages in scripts using the set -x option. | |