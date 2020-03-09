# Restore PingDirectory

Restoring PingDirectory for a customer development environment (CDE) is a manual (ClickOps) operation (not a GitOps one) and is required only in the unlikely event of lost or corrupted user data. 

PingDirectory user data is archived to the S3 bucket for the CDE through a Cron job that runs every 6 hours, by default. 

We store the LDAP data in persistent volumes attached to each container (an EBS volume in AWS). So, there’s a 1:1 association between a PingDirectory pod and its EBS volume. The pods are fungible, but the EBS volumes persist. When Kubernetes adds a replacement pod for one that crashed, it ensures that the replacement pod is attached to the EBS volume associated with the crashed pod.

## The restore operation

Currently, the restore operation uses the latest backup only. You'll execute the `kubectl` command from the AWS management node for the CDE.

> See the Versent document [How to connect to CDE through Platform Hub Account - AWS CLI](https://versent-ping.atlassian.net/wiki/spaces/PPSRE/pages/169836573/How+to+connect+to+CDE+through+Platform+Hub+Account+-+AWS+CLI) for instructions in connecting to the AWS management node for the CDE.

1. Connect to the AWS management node for the CDE, and enter:

   ```bash
   sudo bash
   mkdir ~/k8s
   cd ~/k8s
   cp /usr/local/bin/{kubectl,kubeseal,fluxctl} /bin
   aws eks update-kubeconfig --name <CDE> --region us-east-2
   ```

   Where \<CDE> is the name of the CDE to use.

2. To restore, enter:

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/pingidentity/ping-cloud-base/v1.1-release-branch/k8s-configs/ping-cloud/base/pingdirectory/aws/restore.yaml -n ping-cloud
   ```

## Manually trigger a backup

You can also trigger a PingDirectory backup manually from either:

* Master server `ping-directory-0`
* Any PingDirectory server

### Trigger a backup from master server `ping-directory-0`

1. Connect to the AWS management node for the CDE.
2. Delete the existing backup script from the cluster. Enter:

   ```bash
   $ kubectl delete -f https://raw.githubusercontent.com/pingidentity/ping-cloud-base/v1.1-release-branch/k8s-configs/ping-cloud/base/pingdirectory/aws/backup.yaml -n ping-cloud
   ```

3. Run the backup. Enter:

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/pingidentity/ping-cloud-base/v1.1-release-branch/k8s-configs/ping-cloud/base/pingdirectory/aws/backup.yaml -n ping-cloud
   ```

### Trigger a backup from a specified PingDirectory server

1. Connect to the AWS management node for the CDE.
2. Create a temp file on the management node (for example, `/tmp/manual-server-backup.yaml`).
3. Copy the latest backup script to the temp file you created. Enter:

   ```bash
   cp https://raw.githubusercontent.com/pingidentity/ping-cloud-base/v1.1-release-branch/k8s-configs/ping-cloud/base/pingdirectory/aws/backup.yaml <temp-file>
   ```

   Where \<temp-file> is the temp file you created.

4. Open the temp file in a text editor and add the environment variable `BACKUP_RESTORE_POD` under the configMapRef for `pingdirectory-environment-variables`. Specify the PingDirectory server to to use as the value. For example, where the PingDirectory to use for the backup is `pingdirectory-1`:

   ```yaml
     envFrom:
       - configMapRef:
         name: pingdirectory-environment-variables
     env:
       - name: BACKUP_RESTORE_POD
         value: pingdirectory-1
   ```

5. Delete existing backup script from the cluster. Enter:

   ```bash
   kubectl delete -f /tmp/manual-server-backup.yaml -n ping-cloud
   ```

6. Run the backup. Enter:

   ```bash
   kubectl apply -f /tmp/manual-server-backup.yaml -n ping-cloud
   ```
