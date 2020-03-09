# Restore PingFederate

Currently, PingFederate is a stateless application (a K8s Deployment Object). By default, configuration changes in PingFederate Admin are uploaded to the S3 bucket for the customer development environment (CDE) through a Cron job that runs every 5 minutes.

For every new PingFederate Admin deployment, a script deploys the latest backup file existing in S3 for the CDE.

There's no need to do a manual restore for PingFederate. If a recovery condition occurs, PingFederate will automatically use the latest backup file in S3 for the CDE. If no previous data is captured, PingFederate will deploy with the minimal configuration specified by the server profile for the CDE.

## Manually trigger a backup

You can manually trigger a backup, if necessary. You'll execute the `kubectl` command from the AWS management node for the CDE.

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

2. Delete the existing backup script from the cluster. Enter:

   ```bash
   $ kubectl delete -f https://raw.githubusercontent.com/pingidentity/ping-cloud-base/v1.1-release-branch/k8s-configs/ping-cloud/base/pingfederate/aws/backup.yaml -n ping-cloud
   ```

3. Run the backup. Enter:

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/pingidentity/ping-cloud-base/v1.1-release-branch/k8s-configs/ping-cloud/base/pingfederate/aws/backup.yaml -n ping-cloud
   ```
