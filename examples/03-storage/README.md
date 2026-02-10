# Kubernetes Storage Examples

This section covers Kubernetes storage mechanisms - volumes, persistent volumes, and storage classes.

## Prerequisites

- Kubernetes cluster running (minikube, kind, or k3s)
- kubectl configured and working
- Basic understanding of Pods

## Learning Objectives

After completing these examples, you will understand:

1. **EmptyDir**: Temporary storage shared between containers
2. **PersistentVolumeClaim**: Requesting persistent storage
3. **StorageClass**: Different storage types and dynamic provisioning
4. **Access Modes**: How storage can be accessed (RWO, ROX, RWX)

## Examples

### 01: EmptyDir Volume

**File**: [01-emptydir.yaml](01-emptydir.yaml)

Learn:
- EmptyDir provides temporary storage
- Shared between containers in a pod
- Data is lost when pod is deleted
- Can be disk-backed or memory-backed (tmpfs)

**Run**:
```bash
./01-test-emptydir.sh
```

**Key concepts**:
- Created when pod starts
- Deleted when pod is removed
- Shared between all containers in the pod
- Can be backed by disk (default) or memory (tmpfs)

**For LLM serving**:
- Shared scratch space between main container and sidecars
- Temporary caching of downloaded models
- Intermediate results from preprocessing

**Use cases**:
- Shared data between containers
- Temporary scratch space
- Caching during pod lifetime
- Intermediate computation results

---

### 02: PersistentVolumeClaim (PVC)

**File**: [02-persistent-volume-claim.yaml](02-persistent-volume-claim.yaml)

Learn:
- PVC requests storage from cluster
- Data persists beyond pod lifetime
- Access modes (ReadWriteOnce, ReadOnlyMany, ReadWriteMany)
- Dynamic vs static provisioning

**Run**:
```bash
./02-test-persistent-volume-claim.sh
```

**Key concepts**:
- PVC requests storage (like a pod "requests" storage)
- PV is actual storage resource
- Decouples storage from pod lifecycle
- Data persists even if pod is deleted

**For LLM serving**:
- Model checkpoint storage
- Training data storage
- Model weights storage
- Vector database storage

**Access modes**:
| Access Mode | Description | Use Case |
|-------------|-------------|----------|
| ReadWriteOnce (RWO) | Single node read-write | Single model server |
| ReadOnlyMany (ROX) | Many nodes read-only | Shared read-only models |
| ReadWriteMany (RWX) | Many nodes read-write | Distributed training data |
| ReadWriteOncePod (RWOP) | Single pod read-write | Exclusive pod access |

---

### 03: StorageClass and Dynamic Provisioning

**File**: [03-storage-class.yaml](03-storage-class.yaml)

Learn:
- StorageClass defines storage types
- Dynamic provisioning of PVs
- Reclaim policies (Delete, Retain)
- Volume expansion

**Run**:
```bash
./03-test-storage-class.sh
```

**Key concepts**:
- StorageClass: Profile or "class" of storage
- Dynamic provisioning: Automatic PV creation
- Reclaim policy: What happens when PVC is deleted
- Different provisioners for different backends

**For LLM serving**:
- Fast SSD for low-latency model serving
- Standard HDD for checkpoint storage
- Memory-backed storage for high-performance caching

**Common provisioners**:
| Provisioner | Backend | Use Case |
|-------------|---------|----------|
| kubernetes.io/host-path | Local node path | Development/testing |
| kubernetes.io/aws-ebs | AWS EBS | AWS deployments |
| kubernetes.io/gce-pd | GCE Persistent Disk | GCP deployments |
| kubernetes.io/azure-disk | Azure Disk | Azure deployments |
| nfs.csi.k8s.io | NFS | Shared file storage |

---

## Running All Examples

Run all storage examples sequentially:

```bash
./test-all-storage.sh
```

## Cleanup

Clean up all storage examples:

```bash
./cleanup-all-storage.sh
```

Or clean up individual examples:

```bash
kubectl delete -f 01-emptydir.yaml
kubectl delete -f 02-persistent-volume-claim.yaml
kubectl delete -f 03-storage-class.yaml
```

**Note**: PVCs with `Retain` reclaim policy will leave PVs behind. Clean up manually:

```bash
kubectl delete pv <pv-name>
```

## Volume Types Comparison

| Volume Type | Lifetime | Persistent | Use Case |
|-------------|----------|------------|----------|
| EmptyDir | Pod | No | Shared container storage |
| HostPath | Node | Yes | Node-specific storage (dev only) |
| PVC/PV | Until deleted | Yes | Persistent application storage |
| ConfigMap | Cluster | Yes | Configuration data |
| Secret | Cluster | Yes | Sensitive data |

## Storage Recommendations for LLM Serving

| Use Case | Storage Type | Reason |
|----------|--------------|--------|
| Model Checkpoints | PVC (Standard HDD) | Cost-effective, write-once |
| Model Serving | PVC (Fast SSD/NVMe) | Low latency read access |
| Training Data | PVC (RWX) | Shared access for distributed training |
| Cache / Temporary | EmptyDir (tmpfs) | Fastest, but volatile |
| Long-term Archive | Cloud storage (S3/GCS) | Cheapest, object storage |

## Common Commands

### PVC Commands

```bash
# Create PVC from YAML
kubectl apply -f pvc.yaml

# List PVCs
kubectl get pvc

# Describe PVC
kubectl describe pvc <pvc-name>

# Delete PVC
kubectl delete pvc <pvc-name>

# Resize PVC (if StorageClass allows)
kubectl patch pvc <pvc-name> -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
```

### PV Commands

```bash
# List PVs
kubectl get pv

# Describe PV
kubectl describe pv <pv-name>

# Delete PV
kubectl delete pv <pv-name>
```

### StorageClass Commands

```bash
# List StorageClasses
kubectl get sc

# Describe StorageClass
kubectl describe sc <sc-name>

# Set default StorageClass
kubectl patch sc <sc-name> -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Architecture: Storage in LLM Serving

```
┌─────────────────────────────────────────────────────────┐
│                     Model Serving Pod                   │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Container                                        │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Application                                │  │  │
│  │  │  - Reads model weights from /models         │  │  │
│  │  │  - Writes checkpoints to /checkpoints       │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                      │                            │  │
│  │                      ▼                            │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Volume Mounts                              │  │  │
│  │  │  /models → PVC (Fast SSD)                   │  │  │
│  │  │  /checkpoints → PVC (Standard HDD)          │  │  │
│  │  │  /cache → EmptyDir (tmpfs)                  │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ PVC: Fast    │    │ PVC: Standard│    │ EmptyDir     │
│ StorageClass │    │ StorageClass │    │ (tmpfs)      │
│ (SSD/NVMe)   │    │ (HDD)        │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
         │                    │
         ▼                    ▼
┌──────────────┐    ┌──────────────┐
│  PV (Fast)   │    │  PV (Slow)   │
│ Dynamically  │    │ Dynamically  │
│ Provisioned  │    │ Provisioned  │
└──────────────┘    └──────────────┘
```

## Storage Lifecycle

### EmptyDir Lifecycle
1. Pod created → EmptyDir created
2. Containers read/write to EmptyDir
3. Pod deleted → EmptyDir deleted (data lost)

### PVC/PV Lifecycle (Dynamic Provisioning)
1. PVC created with StorageClass
2. Provisioner creates PV automatically
3. PVC binds to PV
4. Pod mounts PVC
5. Pod deleted → PVC still exists
6. PVC deleted → PV deleted (if reclaimPolicy: Delete)

### PVC/PV Lifecycle (Static Provisioning)
1. Admin creates PV manually
2. PVC created
3. PVC binds to matching PV
4. Pod mounts PVC
5. PVC deleted → PV remains (if reclaimPolicy: Retain)
6. Admin manually deletes PV

## Reclaim Policies

| Policy | Behavior | Use Case |
|--------|----------|----------|
| **Delete** | PV deleted when PVC is deleted | Dynamic provisioning, auto cleanup |
| **Retain** | PV remains after PVC deletion | Manual cleanup, data preservation |
| **Recycle** | Run `rm -rf` on volume (deprecated) | Legacy, avoid using |

## Best Practices

1. **Use PVCs for persistent storage** - Decouples storage from pods
2. **Use appropriate access modes** - RWO for most cases, RWX for shared access
3. **Set resource requests** - Specify storage size in PVC
4. **Use StorageClasses** - Define different storage tiers
5. **Monitor storage usage** - Set up alerts for PVC capacity
6. **Plan for growth** - Use StorageClasses with volume expansion enabled
7. **Test reclaim policies** - Understand what happens when PVC is deleted

## Troubleshooting

### PVC stuck in Pending state
```bash
kubectl describe pvc <pvc-name>
# Check for:
# - No available PV (if static provisioning)
# - StorageClass issues (if dynamic provisioning)
# - Insufficient resources
```

### Pod can't mount PVC
```bash
kubectl describe pod <pod-name>
# Check for:
# - PVC not bound
# - Access mode conflicts
# - Node affinity issues
```

### PV stuck in Released state
```bash
# PV is released but not deleted
# Manual cleanup may be required
kubectl delete pv <pv-name>
```

## Next Steps

After mastering Storage:
1. **StatefulSets** - For stateful applications with stable identity
2. **Stateful Apps** - Running databases and distributed systems
3. **Monitoring** - Monitor storage usage and performance
4. **Backup strategies** - Velero, backup solutions

## References

- [Kubernetes Volumes Documentation](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Kubernetes PersistentVolumes Documentation](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Kubernetes StorageClasses Documentation](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)
