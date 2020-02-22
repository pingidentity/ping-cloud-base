# Purpose
This server profile aims at providing a richer featured PingFederate configuration 
that can also include deploying PingFederate Artifacts (Integration Kits).

## artifacts
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

## hooks
This directory contains shell script example that are executed when the container 
comes up

## instance
This directory is intended to hold the minimal configuration needed to bring up
a tenant, it should not contain any 'customer centric' configuration such as
OAuth client definition or applications in PingAccess. It should contain the
minimal configuration needed to bring up PF using PD for admin authentication
and PA using the PF instance as token provider.