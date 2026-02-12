# Custom User-Defined Scheduling

> Learn how to control where Kubernetes pods are scheduled using user-defined scheduling configuration.

---

## Table of Contents

1. [What is User-Defined Scheduling?](#what-is-user-defined-scheduling)
2. [Why Custom Scheduling for LLMs?](#why-custom-scheduling-for-llms)
3. [Scheduling Concepts](#scheduling-concepts)
4. [Examples](#examples)
5. [Practical Examples](#practical-examples)
6. [Advanced Techniques](#advanced-techniques)
7. [Troubleshooting](#troubleshooting)

---

## What is User-Defined Scheduling?

User-defined scheduling allows you to control pod placement without writing a custom scheduler (in Go). Instead, you use **Kubernetes native features** to influence scheduling decisions:

```
┌─────────────────────────────────────────────────────────────┐
│  Default Scheduling                                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Pod → Scheduler → Random available node            │  │
│  │  (No control over where pods land)                    │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  User-Defined Scheduling                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Pod → Scheduler → YOUR RULES → Specific node        │  │
│  │  (You control pod placement)                          │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**Key Insight**: You control scheduling through **pod specifications**, not a separate scheduler binary!

---

## Why Custom Scheduling for LLMs?

### The Challenge: GPU Workloads Have Special Requirements

```
┌─────────────────────────────────────────────────────────────┐
│  LLM Serving Requirements:                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 1. Specific GPU types (H100 vs A100 vs T4)           │  │
│  │ 2. Multiple GPUs per pod (tensor parallelism)        │  │
│  │ 3. High-speed networking between nodes               │  │
│  │ 4. Co-locate pods for multi-node models              │  │
│  │ 5. Spread pods across failure domains                  │  │
│  │ 6. Priority for critical models                       │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### User-Defined Scheduling Solutions

| Requirement | Solution | Kubernetes Feature |
|-------------|----------|---------------------|
| Specific GPU type | Node selector | `nodeSelector` |
| Multiple GPUs | Resource requests | `resources.limits.nvidia.com/gpu` |
| Pod co-location | Pod affinity | `affinity.podAffinity` |
| Spread across nodes | Pod anti-affinity | `affinity.podAntiAffinity` |
| Priority | Priority class | `priorityClassName` |
| Dedicated nodes | Taints/tolerations | `taints`, `tolerations` |
| Zone awareness | Topology spread | `topologySpreadConstraints` |

---

## Scheduling Concepts

### 1. Node Selector

Simple way to schedule to specific nodes:

```yaml
spec:
  nodeSelector:
    gpu-type: "H100"        # Only schedule to H100 nodes
    zone: "us-west-1a"      # Only in specific zone
```

### 2. Node Affinity

More flexible than nodeSelector:

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - matchExpressions:
        - key: nvidia.com/gpu.product
          operator: In
          values: ["H100", "A100-80GB"]
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: node.kubernetes.io/instance-type
            operator: In
            values: ["p4d.24xlarge"]  # AWS
```

### 3. Pod Affinity/Anti-Affinity

Control pod-to-pod placement:

```yaml
spec:
  affinity:
    # Co-locate with specific pods
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values: ["model-server"]
        topologyKey: kubernetes.io/hostname

    # Spread from other pods
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values: ["model-server"]
        topologyKey: kubernetes.io/hostname
```

### 4. Taints and Tolerations

Dedicate nodes to specific workloads:

```yaml
# On the node:
kubectl taint nodes node-1 gpu-only=true:NoSchedule

# On the pod:
spec:
  tolerations:
  - key: "gpu-only"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
```

### 5. Priority Classes

Give certain pods priority:

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority-model
value: 1000
globalDefault: false
---
spec:
  priorityClassName: high-priority-model
```

---

## Examples

### 01: GPU Node Labeling

**File**: [`01-gpu-node-labeling.sh`](01-gpu-node-labeling.sh)

**What you'll learn**:
- How to label nodes with GPU information
- GPU types, memory, networking capabilities
- Querying nodes by labels

**Run**:
```bash
./01-gpu-node-labeling.sh
```

---

### 02: Scheduler Profile

**File**: [`02-scheduler-profile-configmap.yaml`](02-scheduler-profile-configmap.yaml)

**What you'll learn**:
- Scheduler configuration profiles
- ConfigMap-based scheduling policies
- Default vs custom schedulers

**Run**:
```bash
kubectl apply -f 02-scheduler-profile-configmap.yaml
```

---

### 03: Node Selector with GPU Types

**File**: [`03-gpu-node-selector.yaml`](03-gpu-node-selector.yaml)

**What you'll learn**:
- Schedule pods to specific GPU types
- H100 vs A100 vs T4 selection
- Hard scheduling requirements

**Run**:
```bash
kubectl apply -f 03-gpu-node-selector.yaml
```

---

### 04: Pod Affinity for Co-location

**File**: [`04-pod-affinity-colocation.yaml`](04-pod-affinity-colocation.yaml)

**What you'll learn**:
- Co-locate pods on same node
- Multi-pod model serving (e.g., encoder + decoder)
- Shared memory between pods

**Run**:
```bash
kubectl apply -f 04-pod-affinity-colocation.yaml
```

---

### 05: Pod Anti-Affinity for Spreading

**File**: [`05-pod-anti-affinity-spreading.yaml`](05-pod-anti-affinity-spreading.yaml)

**What you'll learn**:
- Spread pods across different nodes
- High availability for model serving
- Failure domain isolation

**Run**:
```bash
kubectl apply -f 05-pod-anti-affinity-spreading.yaml
```

---

### 06: Taints and Tolerations

**File**: [`06-taints-tolerations-dedicated-nodes.yaml`](06-taints-tolerations-dedicated-nodes.yaml)

**What you'll learn**:
- Mark nodes as dedicated
- Taint nodes to prevent regular pods
- Tolerate taints for GPU workloads

**Run**:
```bash
./06-test-taints.sh
```

---

### 07: Priority Classes

**File**: [`07-priority-classes.yaml`](07-priority-classes.yaml)

**What you'll learn**:
- Create priority classes
- Preemptible vs non-preemptible workloads
- Production vs development environments

**Run**:
```bash
kubectl apply -f 07-priority-classes.yaml
```

---

### 08: Complete Example (LLM Model)

**File**: [`08-llm-model-scheduling.yaml`](08-llm-model-scheduling.yaml)

**What you'll learn**:
- Combine all scheduling techniques
- Real-world LLM model deployment
- Production-ready configuration

**Run**:
```bash
kubectl apply -f 08-llm-model-scheduling.yaml
```

---

## Practical Examples

### Example 1: Schedule to H100 Nodes Only

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llama-3-70b-h100
spec:
  replicas: 2
  template:
    spec:
      # Only H100 nodes
      nodeSelector:
        nvidia.com/gpu.product: H100
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        resources:
          limits:
            nvidia.com/gpu: "4"
```

### Example 2: Spread Across Zones

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llama-3-70b-multi-zone
spec:
  replicas: 3
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - topologyKey: topology.kubernetes.io/zone
            labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values: [llama-3-70b-multi-zone]
```

### Example 3: Co-locate Related Pods

```yaml
# Model server + cache on same node
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values: [redis-cache]
        topologyKey: kubernetes.io/hostname
```

---

## Advanced Techniques

### Multi-Dimension Scheduling

Combine multiple scheduling requirements:

```yaml
spec:
  affinity:
    # 1. Node affinity: H100 nodes only
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - matchExpressions:
        - key: nvidia.com/gpu.product
          operator: In
          values: [H100]

    # 2. Pod affinity: Co-locate with monitoring
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values: [prometheus]
        topologyKey: kubernetes.io/hostname

    # 3. Pod anti-affinity: Spread from other models
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values: [model-serving]
          topologyKey: kubernetes.io/hostname

  # 4. Tolerations: Accept dedicated GPU nodes
  tolerations:
  - key: "nvidia.com/gpu"
    operator: "Exists"
    effect: "NoSchedule"

  # 5. Priority: High priority workload
  priorityClassName: high-priority-gpu
```

---

## How NVIDIA Dynamo Uses This

Dynamo doesn't just use the default scheduler. It extends these concepts:

```
┌─────────────────────────────────────────────────────────────┐
│  User-Defined Scheduling (This Folder)                      │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ nodeSelector, affinity, tolerations, priorities      │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Dynamo Scheduler (Next Layer)                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ - Custom scheduling algorithm (not just K8s features) │  │
│  │ - GPU inventory tracking                                 │  │
│  │ - Placement optimization                                 │  │
│  │ - Network topology awareness                             │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**Key difference**:
- **This folder**: Use K8s native features for scheduling control
- **Dynamo scheduler**: Custom binary with advanced placement algorithms

Both are useful! You often use them together.

---

## Files in This Directory

| File | Purpose |
|------|---------|
| [`01-gpu-node-labeling.sh`](01-gpu-node-labeling.sh) | Label nodes with GPU info |
| [`02-scheduler-profile-configmap.yaml`](02-scheduler-profile-configmap.yaml) | Scheduler configuration |
| [`03-gpu-node-selector.yaml`](03-gpu-node-selector.yaml) | GPU type selection |
| [`04-pod-affinity-colocation.yaml`](04-pod-affinity-colocation.yaml) | Pod co-location |
| [`05-pod-anti-affinity-spreading.yaml`](05-pod-anti-affinity-spreading.yaml) | Pod spreading |
| [`06-taints-tolerations-dedicated-nodes.yaml`](06-taints-tolerations-dedicated-nodes.yaml) | Dedicated nodes |
| [`07-priority-classes.yaml`](07-priority-classes.yaml) | Priority classes |
| [`08-llm-model-scheduling.yaml`](08-llm-model-scheduling.yaml) | Complete example |

---

## Key Takeaways

1. **You don't always need a custom scheduler** - K8s has powerful built-in features
2. **Node selector** - Simple "schedule to nodes with these labels"
3. **Affinity** - Co-locate or spread pods based on other pods
4. **Taints/Tolerations** - Reserve nodes for specific workloads
5. **Priority classes** - Control which pods get scheduled first
6. **Combine techniques** - Use multiple approaches together for complex requirements

---

## Next Steps

After mastering user-defined scheduling:
1. **Multi-node serving** - Apply these techniques to LLM deployments
2. **Dynamo scheduler** - Learn about custom scheduler binaries
3. **Production patterns** - Combine with autoscaling and HPA

---

## References

- [Kubernetes Scheduler Configuration](https://kubernetes.io/docs/reference/scheduling/)
- [Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/#node-affinity)
- [Pod Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/#pod-affinity)
- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/#taints-and-tolerations)
- [Priority Classes](https://kubernetes.io/docs/concepts/scheduling-eviction/#priority-classes)
