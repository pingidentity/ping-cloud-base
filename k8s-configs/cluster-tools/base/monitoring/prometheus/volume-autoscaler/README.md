# Kubernetes Volume / Disk Autoscaler (via Prometheus)

This folder contains a [Kubernetes controller](https://kubernetes.io/docs/concepts/architecture/controller/) that automatically increases the size of a Persistent Volume Claim (PVC) in Kubernetes when it is nearing full (either on space OR inode usage). Initially engineered based on AWS EKS, this should support any Kubernetes cluster or cloud provider which supports dynamically hot-resizing storage volumes in Kubernetes.

Keeping your volumes at a minimal size can help reduce cost, but having to manually scale them up can be painful and a waste of time for a DevOps / Systems Administrator. This is often used on storage volumes against things in Kubernetes such as [Prometheus](https://prometheus.io), [MySQL](https://artifacthub.io/packages/helm/bitnami/mysql), [Redis](https://artifacthub.io/packages/helm/bitnami/redis), [RabbitMQ](https://bitnami.com/stack/rabbitmq/helm), or any other stateful service.

Currently we're using it to manage space of Opensearch hot cluster storage, that running with gp3 StorageClass. This StorageClass has some special features and limitations:

**Durability**

99.8% - 99.9% durability (0.1% - 0.2% annual failure rate)

**Use cases**

-   Transactional workloads
    
-   Virtual desktops
    
-   Medium-sized, single-instance databases
    
-   Low-latency interactive applications
    
-   Boot volumes
    
-   Development and test environments
   

**Volume size**

1 GiB - **16 TiB**


**Max IOPS per volume** (16 KiB I/O)

16,000

**Max throughput per volume**

1,000 MiB/s

**Amazon EBS Multi-attach**

Not supported

**Limitations**

-  Autoscaler must wait at least 21600 seconds (6 hours) after first scaling event before scaling this volume again - it's AWS EBS limitation. For good measure we add an extra 10 minutes to this, so 22200 seconds are set currently:

```
volume.autoscaler.kubernetes.io/scale-cooldown-time: "22200"
```

- All PVCs across cluster that shouldn't be affected by volume autoscaler must be annotated manually with 'ignore' annotation for preventing unwanted operations:

```
annotations:
    volume.autoscaler.kubernetes.io/ignore: "true"
```


More info:
[Repo: Kubernetes Volume / Disk Autoscaler](https://github.com/DevOps-Nirvana/Kubernetes-Volume-Autoscaler)
[Amazon EBS volume types](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html)
[General Purpose SSD volumes](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/general-purpose.html)