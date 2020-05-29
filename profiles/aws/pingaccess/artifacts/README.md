# PingAccess Artifact Service

This document contains the required information to upload PingAccess Artifact Plugins 
(Integration Kits) to a S3 Bucket. It also contains information about the directory structure expected for the artifacts in the artifact repository.

# Manual Upload

All PingAccess plugins are assumed to be custom. Therefore, you must have read/write access to a private S3 bucket. In Ping Cloud Private Tenant that S3 bucket repository will be mapped to the environment variable `${ARTIFACT_REPO_URL}`. 

- ARTIFACT_REPO_URL<br/>For example, export ARTIFACT_REPO_URL=s3://<BUCKET_NAME>

When uploading your custom plugin to S3, you must use the following folder structure:

`${ARTIFACT_REPO_URL}/pingaccess/<ARTIFACT_NAME>/<ARTIFACT_VERSION>/<ARTIFACT_NAME>-<ARTIFACT_VERSION>-runtime.zip`

- For example, an artifact zip of the format <ARTIFACT_NAME>-<ARTIFACT_VERSION>.zip would look like:
    ${ARTIFACT_REPO_URL}/pingaccess/sample-rules/6.0.2/sample-rules-6.0.2-runtime.zip

- The artifact zip, <ARTIFACT_NAME>-<ARTIFACT_VERSION>.zip, must use the following format:
    * /lib/
    * /lib/*.jar

```
Note: The artifact plugin deployment process is automated and expects the structure above.
```

# Usage - Add / Update Plugin
The artifacts available within the S3 bucket can be deployed to PingAccess server profile
through a JSON specification as shown below,

```
[
  {
    "name": "<ARTIFACT_1_NAME>",
    "version": "<ARTIFACT_1_VERSION>",
    "source": "private", (Default is "private")
    "operation": "add" (Default is "add")
  },
  {
    "name": "<ARTIFACT_2_NAME>",
    "version": "<ARTIFACT_2_VERSION>",
    "source": "private", (Default is "private")
    "operation": "add" (Default is "add")
  }
]
```

Simply upload the JSON file to the following location within server profiles
and the artifacts within this list will be downloaded from the artifact repo
and deployed to PingAccess.

- aws/pingaccess/artifacts/artifact-list.json