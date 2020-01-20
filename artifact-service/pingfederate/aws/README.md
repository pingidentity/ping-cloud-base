# PingFederate Artifact Service

This directory contains the scripts required to upload PingFederate Artifacts 
(Integration Kits) to an S3 Bucket. The bucket will be created if it doesn't already
exist. The artifact name and version are extracted from the source file and uploaded 
to the bucket. 

For example, an artifact zip of the format <ARTIFACT_NAME>-<ARTIFACT_VERSION>.zip will 
be uploaded to the following location,

${ARTIFACT_REPO_BUCKET}/pingfederate/<ARTIFACT_NAME>/<ARTIFACT_VERSION>/<ARTIFACT_NAME>-<ARTIFACT_VERSION>-runtime.zip

# Upload

The following tools must be set up and configured correctly:

- curl
- unzip
- aws (AWS config and credentials are properly configured to allow access to the bucket.)

To upload all supported Integration Kits to the S3 bucket, simply run:

```
./upload-all.sh <S3_BUCKET_URL> 
```

To make it easier the location of the S3 bucket can be exported through the 
following environment variable instead of passing it as an argument.

- ARTIFACT_REPO_BUCKET

For example, export ARTIFACT_REPO_BUCKET=<URL_TO_S3_BUCKET>

To upload a specific Integration Kit to the S3 bucket, simply run:

```
./upload-artifact.sh <HTTPS_URL_TO_SOURCE_ARTIFACT_ZIP> <S3_BUCKET_URL> 
```

# Usage
The artifacts available within the S3 bucket can be deployed to PingFederate
through a JSON specification as shown below,

```
[
  {
    "name": "<ARTIFACT_1_NAME>",
    "version": "<ARTIFACT_1_VERSION>"
  },
  {
    "name": "<ARTIFACT_2_NAME>",
    "version": "<ARTIFACT_2_VERSION>"
  }
]
```

Simply upload the JSON file to the following location within server profiles
and the artifacts within this list will be downloaded from the artifact repo
and deployed to PingFederate.

- baseline/pingfederate/artifacts/artifact-list.json

Note: The artifact repo environment variable (ARTIFACT_REPO_URL) containing the
base location of the artifact repo needs to exist for the artifacts to be deployed.