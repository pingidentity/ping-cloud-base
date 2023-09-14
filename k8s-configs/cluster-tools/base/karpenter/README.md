# Karpenter v0.29.2

## Compatibility
Karpenter is tested with Kubernetes v1.21+


## WorkerNode
- The new AWS NodeGroup name core is available to host karpenter, and some critical resources.
- The deployment of karpenter includes affinity rules to ensure that pods are only scheduled to run on node groups, rather than any other nodes that may have been provisioned by karpenter.
- Note: We encountered an issue with AWS Fargate during our Proof of Concept (POC). However, as part of our improvement plan, we will retire the current worker node and begin implementing AWS Farget to host critical pods.


## AWSNodeTemplate
- We define a custom resource within the provider definition, where we can input AWS-specific details that we want Karpenter to use when it launches nodes
  * subnetSelector, discovers tagged subnets to attach to instances.
    karpenter.sh/discovery: <CLUSTER_NAME>
  * securityGroupSelector, discovers tagged security groups to attach to instances.
    karpenter.sh/discovery: <CLUSTER_NAME>
  * blockDeviceMappings, configures storage devices for the instance.
    deviceName: /dev/xvda  volumeSize: 120Gi  volumeType: gp3  encrypted: true


## Provisioner
```sh
providerRef:
    name: <NAME>
```
The Provisioner sets constraints on the nodes that can be created by Karpenter and the pods that can run on those nodes. By default there will be three provisioners default, pd-only and pgo-only


### Limits
Resource limits constrain the total size of the cluster. Limits prevent Karpenter from creating new instances once the limit is exceeded.

1. default,
```sh
limits:
    resources:
      cpu: 250
      memory: 750Gi
```

Note: With the specified limits the scaling of PF/PA/PA-WAS runtimes up to 15 replicas is accommodates for v1.19 release deployment. 

2. pd-only,
```sh
limits:
    resources:
      cpu: 64
      memory: 500Gi
```

Note: With the specified limits the scaling of PD runtimes up to 10 replicas is accommodates for v1.19 release deployment.

2. pgo-only,
```sh
limits:
    resources:
      cpu: 24
      memory: 50Gi
```

Note:
* The configuration for CPU and memory mentioned above is an approximate value rounded up based on observed consumption in a customer environment.
* It will be adjusted after the performance test.


### Taints

1. pd-only,
   - We will utilize the existing taists/tolerate available for the pingdirectory pod manifest.. `pingidentity.com/pd-only`

2. pgo-only,
   - We will introduce tolerate for pgo to taint `pingidentity.com/pgo-only`
   - This will be provided as a patch to facilitate the migration to Karpenter.


### Enables consolidation
```sh
ttlSecondsAfterEmpty: 30
```
It is a configuration setting that specifies how long Karpenter should wait before terminating an empty resource.


### Architecture
Karpenter supports amd64 nodes, and arm64 nodes. Recommandation from Karpenter team is to have it set to one or other.

Note:
- pgo-only provisioner, as we move forward with implementing ARM nodes for P1AS, we will configure it to utilize amd64 due to the unavailability of PGO image for ARM.
- During the upgrade process, we will patch to modify the PGO deployment by incorporating a node selector and taint.


### Capacity Type
Karpenter prioritizes Spot offerings if the provisioner allows Spot and on-demand instances. If the provider API (e.g. EC2 Fleet's API) indicates Spot capacity is unavailable, Karpenter caches that result across all attempts to provision EC2 capacity for that instance type and zone for the next 45 seconds. If there are no other possible offerings available for Spot, Karpenter will attempt to provision on-demand instances, generally within milliseconds.

Note:
-  On-demand instances will only be utilized by the prod.
-  For all other instances, spot instances will be set as the primary option, with a fallback to on-demand instances if spot instances are not available.
-  If any issues arise in the customer or other environments, we have the option to modify the provisioner to utilize on-demand instances. Instructions for making this adjustment will be included in the release documentation.


### Instance Category (Instance Types)
Leaving these requirements undefined is recommended, as it maximizes choices for efficiently placing pods.


Note:
- Due to the limited CIDR (Classless Inter-Domain Routing) for each CDE, some of our customers have encountered IP limitations when scaling out to handle the load.
- Each instance consume some IPs and have ENIs + IP limits, Karpenter provisioning smaller instance could be cost effective but at the same time it might lead to consuming more IPs and hitting the IP limits.
- Each instance consumes a certain number of IPs and has ENIs (Elastic Network Interfaces) with IP limits. While provisioning smaller instances with Karpenter may be cost-effective, it can also result in higher IP consumption and potentially reaching the IP limits.
- It is essential to ensure that the type of node provisioned by Karpenter can handle at least the same or a greater number of workloads.
- After completing the performance test, we will review and reassess this configuration.


## Drift
If users annotate their own nodes with karpenter.sh/voluntary-disruption: "drifted". Karpenter will respect the annotation and deprovision the nodes.


## Disabling Deprovisioning
Pods can be opted out of eviction by setting the annotation karpenter.sh/do-not-evict: "true" on the pod. This is useful for pods that you want to run from start to finish without interruption.


## Generate Karpenter manifest

```sh
./update-karpenter.sh <KARPENTER_VERSION>
```

Note: If you face `failed to download` error you may need to logout from public.ecr.aws,

```sh
docker logout public.ecr.aws
```


## Remove CAS

```sh
kubectl scale deploy/cluster-autoscaler -n kube-system --replicas=0
```


## Verify Karpenter

```sh
kubectl logs -f -n karpenter -c controller -l app.kubernetes.io/name=karpenter
```
