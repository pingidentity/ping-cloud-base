# StorageClass

In Kubernetes, a StorageClass is an object that defines the different storage configurations available for Persistent Volumes (PVs).

The P1AS StorageClass default parameters,

- `provisioner: ebs.csi.aws.com` This driver is a part of the AWS EBS CSI driver, which implements the CSI specification for EBS volumes. In 1.17 and earlier releases in-tree storage plugin was used.

- `allowVolumeExpansion: true` When a StorageClass is created with allowVolumeExpansion: true, users can create a PersistentVolumeClaim (PVC) with a specific size and then later increase the size of the underlying PV associated with that PVC. This is useful when an application's storage requirements grow over time, and additional storage capacity is needed.

- `reclaimPolicy: Delete` reclaimPolicy parameter is used in a PersistentVolume (PV) object to specify what should happen to the PV's storage when the PV is released from its PersistentVolumeClaim (PVC). When not defined, delete is the default behaviour.

- `volumeBindingMode: WaitForFirstConsumer` is a setting that specifies how volumes are bound to pods that require them.

- `csi.storage.k8s.io/fstype: ext4` specify the file system type to be used when mounting a volume provided by a CSI (Container Storage Interface) driver.

- `encrypted: "true"` indicate that a Kubernetes volume should be encrypted.

- `type: gp3` specify the storage class of an Amazon Elastic Block Store (EBS) volume in Kubernetes. In Beluga release v1.18, all the storage types are migrated to GP3, whereas GP2 and IO were in use in earlier releases.

- `mountOptions: -discard` allows a volume to automatically discard (trim or zero) blocks that are no longer needed by the file system. As per AWS recommendation It should only be enabled in the storage class if necessary for specific implementation design and sufficient testing beforehand; It should remain disabled otherwise.


## Notes
  - `mountOptions: -discard` After discussing with the team during Beluga office hours, the team decided to enable trim for data-intensive workloads for example opensearch-sc1, pingdirectory-gp3 and pgo-gp3.


## Example

```yaml
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: <PRODUCT_NAME>-gp3
  allowVolumeExpansion: true
  provisioner: ebs.csi.aws.com
  reclaimPolicy: Delete
  volumeBindingMode: WaitForFirstConsumer
  parameters:
    csi.storage.k8s.io/fstype: ext4
    encrypted: "true"
    type: gp3
  mountOptions:
    - discard
```
