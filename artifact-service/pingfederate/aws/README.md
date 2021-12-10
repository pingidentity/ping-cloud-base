# PingFederate Artifact Service

This directory contains the scripts required to upload existing PingFederate Artifacts 
(Integration Kits) to an S3 Bucket. The bucket will be created if it doesn't already
exist. The runtime components are extracted from the source file and uploaded 
to the bucket. 

For example, an artifact zip of the format <ARTIFACT_NAME>-<ARTIFACT_VERSION>.zip will 
be uploaded to the following location,

${ARTIFACT_REPO_BUCKET}/pingfederate/<ARTIFACT_NAME>/<ARTIFACT_VERSION>/<ARTIFACT_NAME>-<ARTIFACT_VERSION>-runtime.zip

# Required Runtime Specification

The required structure for runtime artifact zips to be used with ping-cloud-base is as follows,

```
Zip Name: 
    <ARTIFACT_NAME>-<ARTIFACT-VERSION>-runtime.zip
Contents:
        Legal.pdf
      config
        data.zip
      dist/pingfederate/server/default
        deploy
          pf-duo-security-adapter-3.0.jar
        conf
          language-packs
            iovation-messages.properties
        lib
          pf-authn-api-sdk-0.54.jar
      sample
        ...
      metadata
        zoom-saml-metadata.xml

```
Standard IKs doc : https://docs.google.com/document/d/1aAX1qL6JcLZZHRmuvqCwJbEHlQeFH8Rc4bEbiu3pTXg/edit#
# Upload

The following tools must be set up and configured correctly:

- curl
- unzip
- aws (AWS config and credentials are properly configured to allow access to the bucket.)

## Upload supported public kits

To upload all supported Integration Kits to a public S3 bucket, simply run:

```
./upload-all.sh s3://<BUCKET_NAME> <ARTIFACT_SOURCE_URL>
```

To make it easier the location of the S3 bucket can be exported through the 
following environment variable instead of passing it as an argument.

- ARTIFACT_REPO_BUCKET

For example, export ARTIFACT_REPO_BUCKET=s3://<BUCKET_NAME>

## Upload an existing kit

To upload an existing Integration Kit to the S3 bucket, simply run:

```
./upload-artifact.sh <HTTPS_URL_TO_SOURCE_ARTIFACT_ZIP> <ARTIFACT_VISIBILITY> s3://<BUCKET_NAME> 
```

ARTIFACT_VISIBILITY can be either "public" or "private". Setting this arg to "public" will make the artifact 
publicly accessible through https after being uploaded.

## Upload runtime IK 

If the zip file is in the specified format (as mentioned in the Specification section), it can
be uploaded directly to the S3 bucket using AWS console or other means (such as aws cli).

# Usage
The artifacts available within the S3 bucket can be deployed to PingFederate
through a JSON specification as shown below,

```
[
  {
    "name": "<ARTIFACT_1_NAME>",
    "version": "<ARTIFACT_1_VERSION>".
    "source": "public | private" (Default is "public")
  },
  {
    "name": "<ARTIFACT_2_NAME>",
    "version": "<ARTIFACT_2_VERSION>"
    "source": "public | private" (Default is "public")
  }
]
```

Simply upload the JSON file to the following location within server profiles
and the artifacts within this list will be downloaded from the artifact repo
and deployed to PingFederate.

- aws/pingfederate/artifacts/artifact-list.json

```
For private plugins the environment variable ARTIFACT_REPO_URL needs to point to the private artifact repo.
```

```
Public plugins are downloaded through the following URL by default,

    https://ping-artifacts.s3-us-west-2.amazonaws.com

The public repo URL can be updated through the environment variable PING_ARTIFACT_REPO_URL.
```