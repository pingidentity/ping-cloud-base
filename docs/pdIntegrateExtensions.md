# Integrating extensions into PingDirectory

1. Create an S3 bucket to store the runtime ZIP files of extensions specific to a customer. You can do this from AWS Management console or the AWS CLI. To use the AWS CLI, enter:

   ```bash
   aws s3api create-bucket --bucket <bucketName> --region <region> --create-bucket-configuration LocationConstraint=<region>
   ```

   Where \<region> is the region in which the bucket is to be available.

   > Make sure you have permissions to upload to the S3 bucket you created.

2. For the S3 bucket, create the following folder structure:

   ```text
   <bucketName>
      pingdirectory
        <extension-name>
          <extension-version>
   ```

3. Use this structure and format to create the runtime ZIP files:

   ```text
   Zip Name: 
       <extension-name>-<extension-version>-runtime.zip
   Contents:
       - deploy
           - <extension-name>.jar 
           - [Optional] <extension>.war
       - conf 
           - template
           - language-packs
   ```

   For \<extension-name>, the dependent libraries must be shaded and included within the adapter jar itself.

   You need to specify the `-conf` section only if the extensions template and language-packs.

   > Make sure the deploy and conf folders are at the root level inside the artifact zip.

4. Upload the \<extension-name>-\<extension-version>-runtime.zip file to the S3 bucket you created. For example:

   ```bash
   aws s3 sync "<local-path>" s3://<bucketName>/pingdirectory/<extension-name>/<extension-version>
   ```

5. When you've uploaded to the S3 bucket the extensions you want to deploy to PingDirectory, create a JSON file named `artifact-list.json` specifying the extensions, and using this format:

   ```json
   [
     {
       "name": "<extension",
       "version": "<extensionon>".
       "source": "private"
     },
     {
       "name": "<extension",
       "version": "<extensionon>"
       "source": "private"
     }
   ]
   ```

   The default value for `source` is "public".

6. Upload the `artifact-list.json` file to the directory `profiles/pingdirectory/artifacts` for the PCPT customer hub account. It will then be automatically deployed to PingDirectory.
