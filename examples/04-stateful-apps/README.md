# Stateful Applications Examples

This section covers Kubernetes StatefulSets - for managing stateful applications with stable identity.

## Prerequisites

- Kubernetes cluster running (minikube, kind, or k3s)
- kubectl configured and working
- Understanding of Pods, Deployments, and Services

## Learning Objectives

After completing these examples, you will understand:

1. **StatefulSet**: For stateful applications with stable identity
2. **Headless Services**: Required for StatefulSet DNS entries
3. **Stable Network Identity**: Ordered pod naming and stable DNS
4. **Stable Storage**: Per-pod persistent volumes

## Examples

### 01: StatefulSet Basics

**File**: [01-statefulset.yaml](01-statefulset.yaml)

Learn:
- StatefulSet provides stable network identity
- Ordered pod naming (web-0, web-1, web-2)
- Headless service for DNS entries
- Per-pod PVCs for stable storage
- Ordered deployment and scaling

**Run**:
```bash
./01-test-statefulset.sh
```

**Key concepts**:
- Pods have stable names (web-0, web-1, web-2)
- DNS: `web-0.nginx-headless.default.svc.cluster.local`
- Each pod gets its own PVC
- Ordered deployment: web-0 → web-1 → web-2
- Data persists across pod restarts

**StatefulSet vs Deployment**:
| Feature | Deployment | StatefulSet |
|---------|-----------|-------------|
| Pod names | Random hash | Ordered (web-0, 1, 2) |
| Network | Unstable | Stable DNS names |
| Storage | Shared PVC | Per-pod PVCs |
| Ordering | Unordered | Ordered deployment |
| Use case | Stateless apps | Stateful apps |

---

### 02: StatefulSet for Distributed Training

**File**: [02-distributed-training.yaml](02-distributed-training.yaml)

Learn:
- Using StatefulSet for distributed LLM training
- Rank extraction from pod name
- DNS-based pod discovery
- Checkpoint storage on per-pod PVCs
- Framework integration (PyTorch DDP, DeepSpeed)

**Run**:
```bash
./02-test-distributed-training.sh
```

**Key concepts**:
- Each pod has a stable rank (from pod name)
- Rank 0 is the master/primary
- Workers can reach master at stable DNS name
- Checkpoints stored on per-pod PVCs
- Resume training from checkpoint on pod restart

**Distributed Training Setup**:
```
trainer-0 (Rank 0 - Master)
  ├── DNS: trainer-0.training
  ├── PVC: checkpoints-trainer-0
  └── Role: Coordinates training

trainer-1 (Rank 1 - Worker)
  ├── DNS: trainer-1.training
  ├── PVC: checkpoints-trainer-1
  └── Role: Processes data shard 1

trainer-2 (Rank 2 - Worker)
  ├── DNS: trainer-2.training
  ├── PVC: checkpoints-trainer-2
  └── Role: Processes data shard 2
```

**Framework Integration**:
```bash
# PyTorch DDP
export MASTER_ADDR=trainer-0.training
export RANK=$(hostname | rev | cut -d- -f1 | rev)
python -m torch.distributed.launch --nproc_per_node=1 train.py

# DeepSpeed
ds_launch --master_addr=trainer-0.training --world_size=3 train.py
```

---

## Running All Examples

Run all stateful app examples sequentially:

```bash
./test-all-stateful-apps.sh
```

## Cleanup

Clean up all stateful app examples:

```bash
./cleanup-all-stateful-apps.sh
```

Or clean up individual examples:

```bash
kubectl delete -f 01-statefulset.yaml
kubectl delete -f 02-distributed-training.yaml
```

**Note**: PVCs will be deleted when StatefulSet is deleted (default reclaimPolicy).

## StatefulSet Key Features

### 1. Stable Network Identity
- Pods named: `web-0`, `web-1`, `web-2`, ...
- DNS: `web-0.service-name.namespace.svc.cluster.local`
- Identity persists across pod restarts

### 2. Stable Storage
- Each pod gets its own PVC
- PVC named: `www-web-0`, `www-web-1`, `www-web-2`, ...
- Data persists even if pod is deleted and recreated

### 3. Ordered Deployment
- `web-0` starts first
- `web-1` starts after `web-0` is ready
- `web-2` starts after `web-1` is ready

### 4. Ordered Scaling
- Scale up: `web-3` starts after `web-2` is ready
- Scale down: `web-2` terminates before `web-1`

### 5. Ordered Rolling Updates
- `web-2` updates first
- `web-1` updates after `web-2` is ready
- `web-0` updates last

## Headless Service

A headless service (`clusterIP: None`) is required for StatefulSets:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
spec:
  clusterIP: None  # Headless service
  selector:
    app: nginx
  ports:
  - port: 80
```

**Why headless?**
- Creates DNS records for each pod
- No cluster IP to load balance
- Direct pod-to-pod communication
- Enables stable network identity

## Common Commands

```bash
# Create StatefulSet
kubectl apply -f statefulset.yaml

# List StatefulSets
kubectl get statefulset

# Describe StatefulSet
kubectl get statefulset web

# Scale StatefulSet
kubectl scale statefulset web --replicas=5

# Show StatefulSet pods
kubectl get pods -l app=nginx-stateful

# Delete StatefulSet (cascades to pods and PVCs)
kubectl delete statefulset web

# Delete pods only (PVCs preserved)
kubectl delete pod web-0 web-1

# Show PVCs
kubectl get pvc -l app=nginx-stateful
```

## Volume Claim Templates

StatefulSets use `volumeClaimTemplates` to create PVCs:

```yaml
volumeClaimTemplates:
- metadata:
    name: www
  spec:
    accessModes: [ "ReadWriteOnce" ]
    resources:
      requests:
        storage: 1Gi
```

Each pod gets its own PVC: `www-web-0`, `www-web-1`, etc.

## When to Use StatefulSet

**Use StatefulSet for**:
- Databases (MySQL, PostgreSQL, MongoDB)
- Distributed systems (ZooKeeper, etcd, Consul)
- Distributed training (PyTorch DDP, DeepSpeed)
- Message queues (Kafka, RabbitMQ)
- Any application requiring:
  - Stable network identity
  - Stable storage
  - Ordered deployment/scaling

**Use Deployment for**:
- Stateless web applications
- APIs
- Microservices
- Any application that doesn't require stable identity

## Architecture: StatefulSet in LLM Training

```
┌─────────────────────────────────────────────────────────────┐
│                    Distributed Training                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  trainer-0   │  │  trainer-1   │  │  trainer-2   │      │
│  │  (Rank 0)    │  │  (Rank 1)    │  │  (Rank 2)    │      │
│  │              │  │              │  │              │      │
│  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌────────┐  │      │
│  │  │PyTorch │  │  │  │PyTorch │  │  │  │PyTorch │  │      │
│  │  │  DDP   │  │  │  │  DDP   │  │  │  │  DDP   │  │      │
│  │  └────┬───┘  │  │  └────┬───┘  │  │  └────┬───┘  │      │
│  │       │      │  │       │      │  │       │      │      │
│  │  ┌────▼───┐  │  │  ┌────▼───┐  │  │  ┌────▼───┐  │      │
│  │  │Checkpt │  │  │  │Checkpt │  │  │  │Checkpt │  │      │
│  │  │ PVC-0  │  │  │  │ PVC-1  │  │  │  │ PVC-2  │  │      │
│  │  └────────┘  │  │  └────────┘  │  │  └────────┘  │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                 │               │
│         └─────────────────┴─────────────────┘               │
│                           │                                 │
│                    ┌──────▼──────┐                         │
│                    │ Headless    │                         │
│                    │ Service     │                         │
│                    │ (training)  │                         │
│                    └─────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

## Best Practices

1. **Always use a headless service** - Required for DNS entries
2. **Use volumeClaimTemplates** - For per-pod persistent storage
3. **Set pod management policy** - `OrderedReady` (default) or `Parallel`
4. **Configure update strategy** - `RollingUpdate` or `OnDelete`
5. **Readiness probes** - Pods must be ready before next pod starts
6. **Graceful shutdown** - Handle SIGTERM for clean shutdown
7. **Resource requests** - Set CPU/memory requests for scheduling

## Troubleshooting

### Pods stuck in pending
```bash
kubectl describe pod web-0
# Check for:
# - Insufficient resources
# - PVC not binding
# - Image pull errors
```

### Pods not starting in order
```bash
# Check pod readiness
kubectl get pods -l app=nginx-stateful

# Readiness probe must pass before next pod starts
kubectl describe pod web-0 | grep -A 5 Readiness
```

### PVC not binding
```bash
kubectl get pvc
kubectl describe pvc www-web-0

# Check storage class
kubectl get storageclass
```

## Next Steps

After mastering StatefulSets:
1. **Advanced Networking** - Network policies, service mesh
2. **Monitoring** - Prometheus, Grafana
3. **Logging** - ELK stack, Loki
4. **Autoscaling** - HPA, VPA, Cluster Autoscaler
5. **Advanced Training** - Kubeflow, MPI Operator

## References

- [Kubernetes StatefulSet Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [StatefulSet Basics](https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/)
- [Running Stateful Applications](https://kubernetes.io/docs/tutorials/stateful-application/mysql-stateful-set/)
- [Distributed Training on Kubernetes](https://kubeflow.org/docs/components/training/)
