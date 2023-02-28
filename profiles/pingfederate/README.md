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
    "version": "<ARTIFACT_1_VERSION>",
    "source": "public | private | ics" (Default is "public"),
    "is_myping_only": "true | false" (Default is "false")
  },
  {
    "name": "<ARTIFACT_2_NAME>",
    "version": "<ARTIFACT_2_VERSION>",
    "source": "public | private | ics" (Default is "public"),
    "is_myping_only": "true | false" (Default is "false")
  }
]
```

Simply upload the JSON file to the following location within server profiles
and the artifacts within this list will be downloaded from the artifact repo
and deployed to PingFederate.

- pingfederate/artifacts/artifact-list.json

```
For private plugins the environment variable ARTIFACT_REPO_URL needs to point to the private artifact repo.
```

```
Public plugins are downloaded through the following URL by default,

    https://ping-artifacts.s3-us-west-2.amazonaws.com

The public repo URL can be updated through the environment variable PING_ARTIFACT_REPO_URL.
```
