# Custom Scheduler Binary

> Learn how to write your own Kubernetes scheduler from scratch, with custom scheduling logic that goes beyond native features.

---

## Table of Contents

1. [What is a Custom Scheduler Binary?](#what-is-a-custom-scheduler-binary)
2. [Why Write Your Own Scheduler?](#why-write-your-own-scheduler)
3. [User-Defined Scheduling vs Custom Scheduler](#user-defined-scheduling-vs-custom-scheduler)
4. [Examples](#examples)
5. [Scheduler Architecture](#scheduler-architecture)
6. [Advanced Topics](#advanced-topics)

---

## What is a Custom Scheduler Binary?

A custom scheduler is a separate program that:
- **Watches the Kubernetes API** for unscheduled pods
- **Implements your own scheduling logic** (in Go, Python, etc.)
- **Binds pods to nodes** via the Kubernetes API

```
┌─────────────────────────────────────────────────────────────────┐
│  Default Kubernetes Scheduler (kube-scheduler)                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ Uses built-in plugins:                                    │ │
│  │ - NodeResourcesFit, NodeAffinity, TaintToleration, etc.   │ │
│  │ You configure via policies, not write code                │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Custom Scheduler (Your Code!)                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ You write the scheduling logic:                           │ │
│  │ - GPU inventory tracking                                  │ │
│  │ - Network topology awareness                             │ │
│  │ - Cost optimization                                      │ │
│  │ - SLA-aware scheduling                                   │ │
│  │ Full control - you decide pod placement!                 │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Why Write Your Own Scheduler?

### Limitations of Native Kubernetes Scheduling

| Requirement | Native K8s | Custom Scheduler |
|-------------|------------|------------------|
| Simple node selection | ✓ nodeSelector | ✓ |
| Co-location/pod affinity | ✓ affinity | ✓ |
| GPU type selection | ✓ labels | ✓ |
| **Cross-node GPU topology** | ✗ Limited | ✓ |
| **Real-time GPU utilization** | ✗ No | ✓ |
| **Cost-based scheduling** | ✗ No | ✓ |
| **Multi-objective optimization** | ✗ Limited | ✓ |
| **Custom metrics** | ✗ No | ✓ |

### When You Need a Custom Scheduler

1. **GPU-Aware Scheduling**
   - Track GPU memory utilization in real-time
   - Understand NVLink topology
   - Bin-pack models across GPUs efficiently

2. **Network Topology Awareness**
   - Prefer same-rack placement
   - NVLink vs PCIe bandwidth
   - Cross-zone latency optimization

3. **Cost Optimization**
   - Spot vs on-demand instance selection
   - Bin-pack to reduce node count
   - Time-based scheduling (cheap hours)

4. **SLA-Driven Scheduling**
   - Latency-based placement
   - Throughput optimization
   - Priority queueing

5. **Custom Constraints**
   - License restrictions
   - Data locality
   - Regulatory compliance

---

## User-Defined Scheduling vs Custom Scheduler

### User-Defined Scheduling (Previous Folder)

```yaml
# 07-user-defined-scheduling/
spec:
  nodeSelector:
    gpu-type: H100
  affinity:
    podAffinity: {...}
    podAntiAffinity: {...}
  tolerations: [...]
  priorityClassName: production
```

**Pros:**
- Uses K8s native features
- Declarative YAML
- Well-tested
- No code to maintain

**Cons:**
- Limited to built-in features
- Can't track real-time GPU utilization
- Can't implement complex algorithms

### Custom Scheduler Binary (This Folder)

```go
// 08-custom-scheduler-binary/
func schedule(pod *v1.Pod, nodes []v1.Node) *v1.Node {
    // Your custom logic!
    availableGPUs := getRealTimeGPUUtilization()
    nvlinkTopology := buildNVLinkGraph(nodes)
    return optimizeForCostAndLatency(pod, availableGPUs, nvlinkTopology)
}
```

**Pros:**
- Full control over scheduling logic
- Can integrate external metrics
- Implement any algorithm
- What NVIDIA Dynamo uses!

**Cons:**
- More complex
- Need to maintain code
- Debugging is harder
- Need to understand K8s API deeply

---

## Examples

### 01: Simple Custom Scheduler (Go)

**File**: [`01-simple-custom-scheduler.go`](01-simple-custom-scheduler.go)

**What you'll learn**:
- Basic scheduler structure
- Watch Kubernetes API for pods
- Filter and score nodes
- Bind pods to nodes

**Run**:
```bash
go run 01-simple-custom-scheduler.go
```

---

### 02: GPU-Aware Scheduler (Python)

**File**: [`02-gpu-aware-scheduler.py`](02-gpu-aware-scheduler.py)

**What you'll learn**:
- Real-time GPU utilization tracking
- NVLink topology awareness
- Multi-GPU placement optimization

**Run**:
```bash
python3 02-gpu-aware-scheduler.py
```

---

### 03: Deploy Custom Scheduler

**File**: [`03-deploy-custom-scheduler.yaml`](03-deploy-custom-scheduler.yaml)

**What you'll learn**:
- Deploy scheduler as Deployment
- RBAC permissions
- Specify schedulerName in pods

**Run**:
```bash
kubectl apply -f 03-deploy-custom-scheduler.yaml
```

---

### 04: Compare with Default Scheduler

**File**: [`04-compare-schedulers.yaml`](04-compare-schedulers.yaml)

**What you'll learn**:
- Side-by-side comparison
- When to use each scheduler
- Performance differences

**Run**:
```bash
kubectl apply -f 04-compare-schedulers.yaml
```

---

## Scheduler Architecture

### How a Custom Scheduler Works

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Watch API for Unscheduled Pods                              │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ Watcher: List pods with spec.nodeName=""                   │ │
│  │ For each pod:                                              │ │
│  │   if pod.spec.schedulerName == "my-scheduler"             │ │
│  │     add to scheduling queue                               │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. Scheduling Loop                                            │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ For each pod in queue:                                    │ │
│  │   1. Filter nodes (hard constraints)                     │ │
│  │   2. Score nodes (soft preferences)                      │ │
│  │   3. Select best node                                    │ │
│  │   4. Bind pod to node                                    │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. Filtering                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ FeasibleNodes = []                                        │ │
│  │ for node in AllNodes:                                     │ │
│  │   if hasEnoughGPU(node, pod):                             │ │
│  │   if toleratesTaints(node, pod):                          │ │
│  │   if matchesLabels(node, pod):                           │ │
│  │     FeasibleNodes.append(node)                           │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. Scoring                                                    │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ NodeScores = {}                                            │ │
│  │ for node in FeasibleNodes:                                │ │
│  │   score = 0                                               │ │
│  │   score += gpuUtilizationScore(node) * 10                │ │
│  │   score += nvlinkScore(node) * 5                          │ │
│  │   score += zoneScore(node) * 2                            │ │
│  │   NodeScores[node] = score                               │ │
│  │ BestNode = max(NodeScores)                               │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  5. Binding                                                    │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ Binding := {                                              │ │
│  │   target: { nodeName: BestNode }                         │ │
│  │ }                                                         │ │
│  │ client.CoreV1().Pods(ns).Bind(pod, Binding)              │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Components

### 1. Informer (Watcher)

Monitors Kubernetes API for changes:

```go
informer := cache.NewSharedIndexInformer(
    &cache.ListWatch{
        ListFunc: func(options metav1.ListOptions) (runtime.Object, error) {
            return client.CoreV1().Pods("").List(context.TODO(), options)
        },
        WatchFunc: func(options metav1.ListOptions) (watch.Interface, error) {
            return client.CoreV1().Pods("").Watch(context.TODO(), options)
        },
    },
    &v1.Pod{},
    time.Minute*10,
    cache.Indexers{},
)
```

### 2. Scheduling Queue

Holds pods waiting to be scheduled:

```go
type SchedulerQueue struct {
    pods    []*v1.Pod
    mutex   sync.Mutex
    cond    *sync.Cond
}

func (q *SchedulerQueue) Add(pod *v1.Pod) {
    q.mutex.Lock()
    defer q.mutex.Unlock()
    q.pods = append(q.pods, pod)
    q.cond.Signal()
}
```

### 3. Filter Plugin

Implements hard constraints:

```go
func FilterGPURequired(pod *v1.Pod, node *v1.Node) bool {
    gpuReq := pod.Spec.Containers[0].Resources.Requests["nvidia.com/gpu"]
    if gpuReq.IsZero() {
        return true
    }
    gpuCap := node.Status.Capacity["nvidia.com/gpu"]
    return !gpuCap.IsZero()
}
```

### 4. Score Plugin

Ranks nodes by preferences:

```go
func ScoreGPUUtilization(pod *v1.Pod, node *v1.Node) int64 {
    // Query GPU utilization (e.g., from NVIDIA DCGM)
    utilization := getGPUUtilization(node.Name)
    // Lower utilization = higher score (binpack)
    return 100 - utilization
}
```

---

## Advanced Topics

### Scheduler Framework (Extending kube-scheduler)

Instead of writing a full scheduler, you can extend `kube-scheduler` with custom plugins:

**Pros:**
- Reuse kube-scheduler infrastructure
- Standard scheduling flow
- Easier to maintain

**Cons:**
- Still need to write Go
- Limited to plugin interfaces

### Scheduler Extender

Run custom logic as an HTTP service:

```go
// kube-scheduler calls your HTTP endpoint
POST /filter
{
  "pod": {...},
  "nodes": [...]
}

Response:
{
  "nodeNames": ["node-1", "node-2"]
}
```

**Pros:**
- Write in any language
- Easier testing

**Cons:**
- HTTP overhead
- Limited integration

---

## Real-World Example: NVIDIA Dynamo

```
┌─────────────────────────────────────────────────────────────────┐
│  Dynamo Scheduler Architecture                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ 1. GPU Inventory Tracking                                 │ │
│  │    - Real-time GPU utilization                           │ │
│  │    - NVLink topology map                                  │ │
│  │    - Memory fragmentation tracking                        │ │
│  └───────────────────────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ 2. Placement Algorithm                                    │ │
│  │    - Multi-objective optimization                        │ │
│  │    - Cost + latency + utilization                        │ │
│  │    - Constraint solving                                   │ │
│  └───────────────────────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ 3. Request Queue Management                               │ │
│  │    - Priority queue                                       │ │
│  │    - batching for efficiency                              │ │
│  │    - timeout management                                   │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Comparison Table

| Feature | User-Defined (07) | Custom Binary (08) |
|---------|-------------------|---------------------|
| Implementation | YAML | Code (Go/Python) |
| Complexity | Low | High |
| Flexibility | Medium | Unlimited |
| GPU Real-time | ✗ | ✓ |
| Custom Metrics | ✗ | ✓ |
| Maintenance | K8s handles | You handle |
| Best For | Simple cases | Complex scenarios |

---

## Next Steps

After mastering custom scheduler binaries:

1. **Multi-node serving** - Apply custom scheduler to LLM deployments
2. **Scheduler framework** - Extend kube-scheduler with plugins
3. **Production patterns** - HA, monitoring, metrics

---

## References

- [Kubernetes Scheduler Configuration](https://kubernetes.io/docs/concepts/scheduling-eviction/scheduler-perf-tuning/)
- [Write a Custom Scheduler](https://kubernetes.io/docs/concepts/scheduling-eviction/custom-scheduler/)
- [Scheduler Framework](https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/)
- [kube-scheduler source code](https://github.com/kubernetes/kubernetes/tree/master/pkg/scheduler)
