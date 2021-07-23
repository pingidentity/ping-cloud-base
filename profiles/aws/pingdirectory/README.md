# Purpose
This server profile aims at providing a richer featured PingDirectory configuration that can then be used with PingFederate

## Extensions
The extensions available within the S3 bucket can be deployed to PingDirectory
through a JSON specification as shown below,

```
[
  {
    "name": "<EXTENSION_1_NAME>",
    "version": "<EXTENSION_1_VERSION>".
    "source": "public | private" (Default is "public")
    "filename": (Can be used to overwrite the default filename "pingidentity.com.${EXTENSION_1_NAME}-${EXTENSION_1_VERSION}.zip")
  },
  {
    "name": "<EXTENSION_2_NAME>",
    "version": "<EXTENSION_2_VERSION>"
    "source": "public | private" (Default is "public")
    "filename": (Can be used to overwrite the default filename "pingidentity.com.${EXTENSION_2_NAME}-${EXTENSION_2_VERSION}.zip")
  }
]
```

Simply upload the JSON file to the following location within server profiles
and the artifacts within this list will be downloaded from the artifact repo
and deployed to PingDirectory.

- pingdirectory/artifacts/artifact-list.json

```
For private plugins the environment variable ARTIFACT_REPO_URL needs to point to the private artifact repo.
```

```
Public plugins are downloaded through the following URL by default,

    https://ping-artifacts.s3-us-west-2.amazonaws.com

The public repo URL can be updated through the environment variable PING_ARTIFACT_REPO_URL.
```