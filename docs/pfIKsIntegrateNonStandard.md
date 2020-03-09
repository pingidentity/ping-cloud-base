# Integrating non-standard Integration Kits into PingFederate

1. Retrieve the customer S3 bucket from the cluster-state-rep by finding the ARTIFACT_REPO_URL value in k8s-configs/pingcloud/env_vars. 

2. Verify the  S3 bucket exists using the CLI. Enter:

   ```bash
   aws s3 ls --profile <hub environment stub>
   ```

3. For the S3 bucket, create the following folder structure:

   ```text
   <bucketName>
     pingfederate
       <IK-name>
         <IK-version>
   ```

4. Use this structure and format to create the runtime ZIP files:

   ```text
   Zip Name: 
       <IK-name>-<IK-version>-runtime.zip
   Contents:
       - deploy
           - <IK-Adapter-name>.jar 
           - [Optional] <IK-war-name>.war
       - conf 
           - template
           - language-packs
   ```

   For \<IK-Adapter-name>, the dependent libraries must be shaded and included within the adapter jar itself.

   You need to specify the `-conf` section only if the IK includes template and language-packs.

   > Make sure the deploy and conf folders are at the root level inside the artifact zip.

5. Upload the \<IK-name>-\<IK-version>-runtime.zip) to the S3 bucket you created. For example:

   ```bash
   aws s3 sync "<local-path>" s3://<bucketName>pingfederate<IK-name><IK-version>
   ```

6. When you've uploaded to the S3 bucket the IKs you want to deploy to PingFederate, create a JSON file named `artifact-list.json` specifying the IKs, and using this format:

   ```json
   [
     {
       "name": "<IK-1-name>",
       "version": "<IK-1-version>".
       "source": "private"
     },
     {
       "name": "<IK-2-name>",
       "version": "<IK-2-version>"
       "source": "private"
     }
   ]
   ```

   The default value for `source` is "public".

7. Upload the `artifact-list.json` file to the directory `profiles/pingfederate/artifacts` for the PCPT customer hub account. It will then be automatically deployed to PingFederate.
