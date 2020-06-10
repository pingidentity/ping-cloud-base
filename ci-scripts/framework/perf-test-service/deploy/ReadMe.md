# Performance Test Service

## Overview

This deployment provides a wrapper around the PingAccess performance test service so it can be deployed to a Kubernetes cluster to support performance testing. The service it self provides several endpoints that either echo components of the HTML request or generate response data that can be verified. It is intended to be used as a back end 'target' for a PingAccess application definition. For more information send an http request to the /usage endpoint of the deployed service.

## Building

Navigate to the ***ci-scripts/framework/perf-test-service/image*** directory and run the build.sh script.

## PingAccess Integration

The perf-service deployment has an associated service definition also called perf-service that exposes port 8080 to the k8s cluster. To reference this from PingAccess define a site with:

    Hostname:   perf-service
    Port:       8080

## Using on personal EKS cluster

Simply navigate to the ***ci-scripts/framework/perf-test-service/deploy*** directory and run the following commands

```bash
    kustomize build . > /tmp/perf.yaml
    kubectl apply -f /tmp/perf.yaml
```

## Using in the Lab or Preview Environments

This is a little more difficult as we don't want the perf-service to be deployed as part of the PingCloud application stack, it needs to be deployed manually from the management node. The expected method for copying files to/from the management node is via an S3 bucket. Copy the *deployment.yaml* & *kustomize.yaml* files to a S3 bucket accessible from the management node and then download to the management node using the AWS CLI. Then deploy as shown above for your local cluster.

Since additional permissions are needed to write to the S3 buckets associated with the PingCloud stack, as the files are small, a simpler approach may be to perform a split screen exit and cut-n-paste from your local git repo file to a file on the management node.
