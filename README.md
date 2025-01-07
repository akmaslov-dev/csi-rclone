# Fork features

1. `linux/arm64` support.
2. Publicly accessible container images.
3. OCI-based registry support for Helm Chart.
4. Small fixes and adjustments.

# CSI rclone mount plugin

This project implements Container Storage Interface (CSI) plugin that allows using [rclone mount](https://rclone.org/) as storage backend. Rclone mount points and [parameters](https://rclone.org/commands/rclone_mount/) can be configured using Secret or PersistentVolume volumeAttibutes. 

## Installation

You can install the CSI plugin via Helm. Please checkout the default values file at `charts/csi-rclone/values.yaml`
in this repository for the possible options on how to configure the installation.

```bash
helm repo add csi-rclone https://akmaslov-dev.github.io/csi-rclone/
helm repo update
helm install csi-rclone csi-rclone/csi-rclone
```

Also you can install Helm Chart directly from OCI-based registry.

```bash
helm install rclone-csi oci://ghcr.io/akmaslov-dev/charts/csi-rclone --version 0.3.6
```

## Usage

The easiest way to use this driver is to just create a Persistent Volume Claim (PVC) with the `csi-rclone-secret-annotation`
storage class. Or if you have modified the storage class name in the `values.yaml` file then use the name you have chosen with 
`-secret-annotation` added at the end of the name. The Helm chart creates 2 storage classes for compatibility reasons. The 
storage class that matches the name in the values file will expect a secret that matches the PVC name to exist in the same namespace
as the PVC. Whereas the storage class that has the suffix `-secret-annotation` will require the PVC to have the `csi-rclone.dev/secretName` annotation.
Note that since the storage is backed by an existing cloud storage like S3 or something similar, the size 
that is requested in the PVC below has no role at all and is completely ignored. It just has to be provided in the PVC specification.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: csi-rclone-example
  namespace: csi-rclone-example
  annotations:
    csi-rclone.dev/secretName: csi-rclone-example-secret
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: csi-rclone-secret-annotation
```

You have to provide a secret with the rclone configuration. The secret has to have a specific format explained below.
The secret can be passed to the CSI driver via the annotation `csi-rclone.dev/secretName`.

The secret requires the following fields:
- `remote`: The name of the remote that should be mounted - has to match the section name in the `configData` field
- `remotePath`: The path on the remote that should be mounted, it should start with the container itself, for example
  for a S3 bucket, if the bucket is called `test_bucket`, then the remote should be at least `test_bucket/`.
- `configData`: The rclone configuration, has to match the JSON schema from `rclone config providers`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: csi-rclone-example-secret
  namespace: csi-rclone-example
type: Opaque
stringData:
  remote: giab
  remotePath: giab/
  configData: |
    [giab]
    type = s3
    provider = AWS
```

### Skip provisioning and create PV directly

This is more complicated but doable. Here you have to specify the secret name in the CSI parameters.
Assuming that the secret that contains the configuration is called `csi-rclone-example-secret` and 
is located in the namespace `csi-rclone-example`, then the PV specification would look as follows.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: csi-rclone-pv-example
spec:
  accessModes:
    - ReadWriteMany
  capacity:
    storage: 10Gi
  csi:
    driver: csi-rclone
    volumeHandle: csi-rclone-pv-example  # same as the PersistentVolumeName
    # For the provisioning to fully work both fields are required even though they both refer to the same secret
    nodePublishSecretRef:
      name: csi-rclone-example-secret
      namespace: csi-rclone-example
    volumeAttributes:
      secretName: csi-rclone-example-secret
      secretNamespace: csi-rclone-example
  persistentVolumeReclaimPolicy: Delete
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pv-claim
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  # If the storage class is not blank then you will get automatic provisioning and the PVC may not be bound
  # to the selected volume.
  storageClassName: ""
  volumeName: "csi-rclone-pv-example"
```
