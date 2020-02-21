# Purpose
This server profile aims at providing a richer featured PingDirectory configuration that can then be used with PingFederate

## config
This directory contains various config batch fragments that are assembled and applied together to set the instance up

## data
This directory contains data to get a sample data set ready as soon as the container is up and running

## extensions
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

- aws/pingdirectory/artifacts/artifact-list.json

```
For private plugins the environment variable ARTIFACT_REPO_URL needs to point to the private artifact repo.
```

```
Public plugins are downloaded through the following URL by default,

    https://ping-artifacts.s3-us-west-2.amazonaws.com

The public repo URL can be updated through the environment variable PING_ARTIFACT_REPO_URL.
```

## hooks
This directory contains shell script example that are executed when the container comes up

## instance
This directory may be used to apply any other file directly to the instance.
See [the basic server profile](https://github.com/pingidentity/server-profile-pingdirectory-basic) for details