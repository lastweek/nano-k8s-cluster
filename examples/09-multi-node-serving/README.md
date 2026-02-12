# Multi-Node Model Serving

> Learn how to deploy large LLMs that span multiple GPU servers, progressively building toward NVIDIA Dynamo's architecture.

---

## Table of Contents

1. [What is Multi-Node Serving?](#what-is-multi-node-serving)
2. [Why Multi-Node for LLMs?](#why-multi-node-for-llms)
3. [Progressive Examples](#progressive-examples)
4. [NVIDIA Dynamo Architecture](#nvidia-dynamo-architecture)
5. [Key Concepts](#key-concepts)

---

## What is Multi-Node Serving?

Multi-node serving deploys a single model across multiple physical servers, each with multiple GPUs.

```
┌─────────────────────────────────────────────────────────────────┐
│  Single-Node Serving (Small Models)                             │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ Server 1: [GPU0, GPU1, GPU2, GPU3]                       │ │
│  │            └── Llama-3-8B (fits in 4 GPUs)               │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Multi-Node Serving (Large Models)                              │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ Server 1: [GPU0, GPU1, GPU2, GPU3]                       │ │
│  │ Server 2: [GPU4, GPU5, GPU6, GPU7]                       │ │
│  │            └── Llama-3-70B (needs 8 GPUs)                │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Why Multi-Node for LLMs?

### Model Size Requirements

| Model | Parameters | GPU Memory (FP16) | GPUs Needed |
|-------|-----------|-------------------|-------------|
| Llama-3-8B | 8B | ~16GB | 1-2 GPUs |
| Llama-3-70B | 70B | ~140GB | 2-4 GPUs |
| DeepSeek-V2 | 236B | ~472GB | 6-8 GPUs |
| DeepSeek-R1 | 32B (MoE) | ~200GB+ | 4-8 GPUs |

### Why Not Just Bigger GPUs?

1. **Cost** - 8x H100 (80GB each) is cheaper than 1x "mega-GPU"
2. **Availability** - H100s are more available than specialized hardware
3. **Scalability** - Add more servers as needed
4. **Flexibility** - Different models can use different GPU counts

### Multi-Node Challenges

```
┌─────────────────────────────────────────────────────────────────┐
│  Challenge 1: How do pods communicate?                          │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ Solution: Headless services + stable DNS                  │ │
│  │   llama-3-70b-0.llama-3-70b.default.svc.cluster.local    │ │
│  │   llama-3-70b-1.llama-3-70b.default.svc.cluster.local    │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Challenge 2: How to coordinate tensor parallelism?             │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ Solution: Distributed init method                        │ │
│  │   --distributed-init-method=tcp://pod-0:5000            │ │
│  │   Each pod knows its rank and world size                 │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Challenge 3: How do clients connect?                           │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ Solution: Router service load balances across pods        │ │
│  │   Request → Router → Pod-0 / Pod-1 / Pod-2               │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Progressive Examples

### 01: Basic StatefulSet
**File**: [`01-basic-statefulset.yaml`](01-basic-statefulset.yaml)

**What you'll learn**:
- What is a StatefulSet
- Stable pod identities (pod-0, pod-1, etc.)
- Compared to Deployments

**Run**:
```bash
kubectl apply -f 01-basic-statefulset.yaml
```

---

### 02: Headless Service
**File**: [`02-headless-service.yaml`](02-headless-service.yaml)

**What you'll learn**:
- Headless services for pod-to-pod communication
- DNS records for each pod
- Why this is critical for distributed systems

**Run**:
```bash
kubectl apply -f 02-headless-service.yaml
# Test DNS: kubectl exec -it test-pod -- nslookup llama-3-70b-0
```

---

### 03: Multi-Node with Tensor Parallelism
**File**: [`03-multi-node-tp.yaml`](03-multi-node-tp.yaml)

**What you'll learn**:
- Deploy model across 2 nodes (4 GPUs each)
- Tensor parallelism setup
- Distributed init method
- Pod anti-affinity for spreading

**Run**:
```bash
kubectl apply -f 03-multi-node-tp.yaml
```

---

### 04: Router Service
**File**: [`04-router-service.yaml`](04-router-service.yaml)

**What you'll learn**:
- Add router/load balancer layer
- Distribute requests across StatefulSet pods
- Health checks and circuit breaking

**Run**:
```bash
kubectl apply -f 04-router-service.yaml
```

---

### 05: Distributed Coordination
**File**: [`05-coordination.yaml`](05-coordination.yaml)

**What you'll learn**:
- Leader election
- Configuration sharing
- Pod readiness coordination
- Graceful startup sequence

**Run**:
```bash
kubectl apply -f 05-coordination.yaml
```

---

### 06: Dynamo-Like Complete
**File**: [`06-dynamo-like.yaml`](06-dynamo-like.yaml)

**What you'll learn**:
- Complete Dynamo-like architecture
- Request queue
- Scheduler integration
- Dynamic scaling

**Run**:
```bash
kubectl apply -f 06-dynamo-like.yaml
```

---

### 07: Autoscaling
**File**: [`07-autoscaling.yaml`](07-autoscaling.yaml)

**What you'll learn**:
- Scale StatefulSets based on metrics
- Custom metrics for queue length
- Zero-downtime scaling

**Run**:
```bash
kubectl apply -f 07-autoscaling.yaml
```

---

### 08: Complete Production Cluster
**File**: [`08-complete-cluster.yaml`](08-complete-cluster.yaml)

**What you'll learn**:
- Everything together
- Monitoring with Prometheus
- Logging
- Disaster recovery

**Run**:
```bash
kubectl apply -f 08-complete-cluster.yaml
```

---

## NVIDIA Dynamo Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  NVIDIA Dynamo Multi-Node Architecture                          │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                                                          │ │
│  │  Client Request                                          │ │
│  │       ↓                                                  │ │
│  │  ┌─────────────────────────────────────────────────────┐ │ │
│  │  │ Dynamo Request Queue                                 │ │ │
│  │  │ - Priority queue                                     │ │ │
│  │  │ - Batching                                           │ │ │
│  │  │ - Timeout management                                 │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  │       ↓                                                  │ │
│  │  ┌─────────────────────────────────────────────────────┐ │ │
│  │  │ Dynamo Scheduler                                     │ │ │
│  │  │ - Custom scheduler (binary)                         │ │ │
│  │  │ - GPU inventory tracking                             │ │ │
│  │  │ - Placement optimization                             │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  │       ↓                                                  │ │
│  │  ┌─────────────────────────────────────────────────────┐ │ │
│  │  │ Model Serving Pods (StatefulSet)                     │ │
│  │  │ ┌────────────┐  ┌────────────┐  ┌────────────┐    │ │ │
│  │  │ │Pod-0       │  │Pod-1       │  │Pod-2       │    │ │ │
│  │  │ │4xGPU H100  │  │4xGPU H100  │  │4xGPU H100  │    │ │ │
│  │  │ │Rank 0      │  │Rank 1      │  │Rank 2      │    │ │ │
│  │  │ └────────────┘  └────────────┘  └────────────┘    │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  │       ↓                                                  │ │
│  │  Response                                                │ │
│  │                                                          │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### How Dynamo Differs from Basic K8s

| Feature | Basic K8s (01-05) | Dynamo (06-08) |
|---------|-------------------|----------------|
| Scheduling | kube-scheduler | Custom scheduler |
| Queueing | None (direct) | Request queue |
| Scaling | HPA (CPU/memory) | Queue-based autoscaling |
| GPU tracking | nvidia.com/gpu count | Real-time GPU memory |
| Placement | Pod anti-affinity | Topology-aware |

---

## Key Concepts

### StatefulSet vs Deployment

```
┌─────────────────────────────────────────────────────────────┐
│  Deployment (Stateless)                                      │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ my-app-7d6f8b9c-xkp2z  → Pod name is random!        │ │
│  │ my-app-7d6f8b9c-mn5qp  → Can't predict DNS           │ │
│  │ my-app-7d6f8b9c-zkl4q  → No stable identity          │ │
│  └───────────────────────────────────────────────────────┘ │
│  Good for: Web servers, APIs (stateless)                    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  StatefulSet (Stateful)                                       │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ llama-3-70b-0          → Stable, predictable!        │ │
│  │ llama-3-70b-1          → DNS: llama-3-70b-0.service  │ │
│  │ llama-3-70b-2          → Each has own PVC             │ │
│  └───────────────────────────────────────────────────────┘ │
│  Good for: Databases, distributed systems, multi-node LLMs  │
└─────────────────────────────────────────────────────────────┘
```

### Headless Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: llama-3-70b
spec:
  clusterIP: None  # ← This makes it "headless"
  selector:
    app: llama-3-70b
```

**Result**: Each pod gets its own DNS record
```
llama-3-70b-0.llama-3-70b.default.svc.cluster.local → 10.0.1.5
llama-3-70b-1.llama-3-70b.default.svc.cluster.local → 10.0.1.6
llama-3-70b-2.llama-3-70b.default.svc.cluster.local → 10.0.1.7
```

### Tensor Parallelism Coordination

```yaml
containers:
- name: vllm
  env:
  - name: WORLD_SIZE
    value: "4"           # Total pods
  - name: RANK
    valueFrom:
      fieldRef:
        fieldPath: metadata.annotations['cortex.io/pod-index']  # 0, 1, 2, 3
  - name: MASTER_ADDR
    value: "llama-3-70b-0.llama-3-70b.default.svc.cluster.local:5000"
```

**How Pods Discover Each Other**:
1. Pod-0 starts → becomes coordinator (rank=0)
2. Pod-1 starts → connects to Pod-0 (rank=1)
3. Pod-2 starts → connects to Pod-0 (rank=2)
4. Pod-3 starts → connects to Pod-0 (rank=3)
5. All connect via headless service DNS

---

## Test Scripts

Each example has a test script:
```bash
./test-01-statefulset.sh      # Test basic StatefulSet
./test-02-headless.sh         # Test DNS resolution
./test-03-multi-node.sh       # Test multi-node TP
./test-04-router.sh           # Test router
./test-05-coordination.sh     # Test coordination
./test-06-dynamo.sh           # Test Dynamo-like
./test-07-autoscaling.sh      # Test autoscaling
./test-08-complete.sh         # Full production test
```

---

## Comparison with Other Examples

| Example | Purpose | Complexity |
|---------|---------|------------|
| `01-basics/deployments` | Simple single-pod serving | ⭐ |
| `07-user-defined-scheduling` | Control where pods land | ⭐⭐ |
| `08-custom-scheduler-binary` | Write custom scheduler | ⭐⭐⭐ |
| **`09-multi-node-serving`** | **Deploy models across servers** | **⭐⭐⭐⭐** |

---

## Prerequisites

- At least 2 nodes with GPUs
- NVIDIA GPU driver installed
- kubectl configured
- (Optional) Kind/minikube with GPU passthrough

---

## Next Steps

After mastering multi-node serving:
1. **Advanced Networking** - Service mesh for inter-pod communication
2. **Observability** - Distributed tracing, GPU metrics
3. **Device Plugins** - Deep dive into GPU management

---

## References

- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Headless Services](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services)
- [NVIDIA Dynamo](https://github.com/ai-dynamo/dynamo)
- [vLLM Distributed Inference](https://docs.vllm.ai/en/latest/serving/distributed_serving.html)
