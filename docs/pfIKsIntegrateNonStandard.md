# Integrating non-standard Integration Kits into PingFederate

1. Create an S3 bucket to store the runtime ZIP files of Integration Kits (IKs) specific to a customer. You can do this from AWS Management console or the AWS CLI. To use the AWS CLI, enter:

   ```bash
   aws s3api create-bucket --bucket <bucketName> --region <region> --create-bucket-configuration LocationConstraint=<region>
   ```

   Where \<region> is the region in which the bucket is to be available.

   > Make sure you have permissions to upload to the S3 bucket you created.

2. For the S3 bucket, create the following folder structure:

   ```text
   <bucketName>
     pingfederate
       <IK-name>
         <IK-version>
   ```

3. Use this structure and format to create the runtime ZIP files:

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

4. Upload the \<IK-name>-\<IK-version>-runtime.zip) to the S3 bucket you created. For example:

   ```bash
   aws s3 sync "<local-path>" s3://<bucketName>pingfederate<IK-name><IK-version>
   ```

5. When you've uploaded to the S3 bucket the IKs you want to deploy to PingFederate, create a JSON file named `artifact-list.json` specifying the IKs, and using this format:

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

6. Upload the `artifact-list.json` file to the directory `profiles/pingfederate/artifacts` for the PCPT customer hub account. It will then be automatically deployed to PingFederate.
