# Karpenter v0.24.0

## Compatibility
Karpenter v0.24.0 is tested with Kubernetes v1.20-v1.24.

## WorkerNode
The new AWS NodeGroup name `core` is available to host karpenter, and some critical resources and tolerance have been added for key `CriticalAddonsOnly` 

## Provisioner
```sh 
providerRef:
    name: <NAME>
```
The Provisioner sets constraints on the nodes that can be created by Karpenter and the pods that can run on those nodes. By default we have included two different provisioner `default` and `pd-only` 

```sh 
karpenter.sh/capacity-type"
```
If not included, the webhook for the AWS cloud provider will default to on-demand

```sh
limits:
    resources:
      cpu: "1000"
      memory: 1000Gi
``` 
Resource limits constrain the total size of the cluster. Limits prevent Karpenter from creating new instances once the limit is exceeded.
  
```sh 
ttlSecondsUntilExpired
```
If omitted, the feature is disabled, and nodes will never expire.  If set to less time than it requires for a node to become ready, the node may expire before any pods successfully start.

```sh 
ttlSecondsAfterEmpty
```
If omitted, the feature is disabled, nodes will never scale down due to low utilization.

```sh
karpenter.sh/do-not-consolidate: "true"
```
Prevent all nodes launched by this Provisioner from being considered in consolidation calculations.

# Architecture 
Karpenter supports amd64 nodes, and arm64 nodes. Recommandation from Karpenter team is to have it set to one or other.

# Capacity Type
Karpenter prioritizes Spot offerings if the provisioner allows Spot and on-demand instances. If the provider API (e.g. EC2 Fleet's API) indicates Spot capacity is unavailable, Karpenter caches that result across all attempts to provision EC2 capacity for that instance type and zone for the next 45 seconds. If there are no other possible offerings available for Spot, Karpenter will attempt to provision on-demand instances, generally within milliseconds.

By deafult, we have two provisioner, `default` and `pd-only`, where the default provisioner uses both spot and on-demand capacity, but for prod CDE, we patch it to use on-demand only. 

# Drift
If users annotate their own nodes with karpenter.sh/voluntary-disruption: "drifted". Karpenter will respect the annotation and deprovision the nodes.

# Disabling Deprovisioning 
Pods can be opted out of eviction by setting the annotation karpenter.sh/do-not-evict: "true" on the pod. This is useful for pods that you want to run from start to finish without interruption.

# Generate Karpenter manifest

```sh
helm template karpenter oci://public.ecr.aws/karpenter/karpenter --version ${KARPENTER_VERSION} --namespace karpenter \
    --set settings.aws.defaultInstanceProfile=KarpenterInstanceProfile \
    --set settings.aws.clusterEndpoint="${CLUSTER_ENDPOINT}" \
    --set settings.aws.clusterName=${CLUSTER_NAME} \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterControllerRole-${CLUSTER_NAME}" \
    --version ${KARPENTER_VERSION} > karpenter.yaml
```

# Remove CAS

```sh
kubectl scale deploy/cluster-autoscaler -n kube-system --replicas=0
```

# Verify Karpenter

```sh
kubectl logs -f -n karpenter -c controller -l app.kubernetes.io/name=karpenter
```
