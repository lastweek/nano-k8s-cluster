# How NVIDIA Dynamo Uses CRDs and Operators

## Overview

NVIDIA Dynamo is built entirely on the **Kubernetes Operator pattern**. It extends Kubernetes with custom resources specifically designed for LLM serving at scale.

## The Dynamo Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        User (kubectl)                           │
│                                                                 │
│  kubectl apply -f my-dynamo-deployment.yaml                     │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Dynamo Custom Resources (CRDs)                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ DynamoGraphDeployment                                      │  │
│  │ - Model configuration (name, path, format)                 │  │
│  │ - Deployment config (tensor parallelism, pipeline)         │  │
│  │ - SLA (latency, throughput)                                │  │
│  │ - Scaling policy                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ DynamoGraphDeploymentRequest                               │  │
│  │ - One-time request                                         │  │
│  │ - Creates deployment, then deleted                        │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Dynamo Operator (The Brain)                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Reconciliation Loop                                        │  │
│  │                                                            │  │
│  │ 1. Watch DynamoGraphDeployment resources                  │  │
│  │ 2. Read spec (model, SLA, placement)                      │  │
│  │ 3. Calculate required resources:                          │  │
│  │    - Number of replicas (based on SLA)                    │  │
│  │    - GPUs per replica (tensor parallelism)                │  │
│  │    - Placement constraints                                 │  │
│  │ 4. Create/Update Kubernetes resources:                     │  │
│  │    - StatefulSet (for stable identity)                    │  │
│  │    - Services (for discovery)                              │  │
│  │    - ConfigMaps (for model config)                        │  │
│  │    - HPA (for scaling)                                     │  │
│  │ 5. Watch actual performance                               │  │
│  │ 6. Adjust if SLA not met                                   │  │
│  │ 7. Update status                                           │  │
│  │ 8. Repeat forever                                         │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Kubernetes Resources (Managed by Dynamo Operator)              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────┐  ┌────────────┐  ┌──────────┐  ┌──────────┐  │
│  │StatefulSet │  │  Service   │  │   HPA    │  │ConfigMap │  │
│  │(Model pods)│  │(Discovery) │  │(Scaling) │  │ (Config) │  │
│  └────────────┘  └────────────┘  └──────────┘  └──────────┘  │
│                                                                 │
│  Plus custom Dynamo resources:                                │
│  - MIG Partitions (GPU slicing)                               │
│  - Device plugins                                             │
│  - Scheduler extensions                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Actual Serving Infrastructure                                  │
│                                                                 │
│  GPU Nodes with:                                               │
│  - Model serving containers (vLLM/TensorRT-LLM)               │
│  - MIG partitions (multi-tenant GPU)                          │
│  - Custom scheduling                                          │
└─────────────────────────────────────────────────────────────────┘
```

## Dynamo's Custom Resources

### DynamoGraphDeployment

```yaml
apiVersion: nvidia.com/v1
kind: DynamoGraphDeployment
metadata:
  name: llama-3-70b
  namespace: default
spec:
  # Model configuration
  model:
    name: llama-3-70b
    format: pytorch
    path: /models/llama-3-70b

  # Deployment configuration
  placement:
    strategy: Spread  # or BinPack
    tensorParallelism: 4
    pipelineParallelism: 1

  # GPU configuration
  gpu:
    type: H100
    memory: 80Gi
    migProfile: null  # or MIG profile for slicing

  # Scaling configuration
  scaling:
    minReplicas: 2
    maxReplicas: 100
    targetMetric: RequestsPerSecond
    targetValue: 50

  # Service Level Agreement
  sla:
    maxLatencyMs: 100
    minThroughput: 100  # requests/second
    p95LatencyMs: 200

  # Serving configuration
  serving:
    port: 8000
    image: nvcr.io/nvidia/vllm:v0.6.3
    env:
    - name: MODEL_PATH
      value: /models/llama-3-70b

status:
  phase: Running
  replicas: 4
  readyReplicas: 4
  currentLatencyMs: 45
  currentThroughput: 120
```

### What the Operator Does

When you create a `DynamoGraphDeployment`, the operator:

#### 1. **Calculates Required Resources**

```python
# Pseudocode from Dynamo operator
def calculate_replicas(spec):
    sla_throughput = spec.sla.minThroughput
    model_throughput = get_model_perf(spec.model.name)

    # Calculate replicas needed
    replicas = ceil(sla_throughput / model_throughput)

    # Apply min/max bounds
    replicas = max(spec.scaling.minReplicas,
                   min(replicas, spec.scaling.maxReplicas))

    return replicas
```

#### 2. **Creates StatefulSet**

```yaml
# Operator creates this StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: llama-3-70b
  labels:
    nvidia.com/dynamo-deployment: llama-3-70b
spec:
  replicas: 4  # Calculated by operator
  serviceName: llama-3-70b
  podManagementPolicy: Parallel  # Dynamo uses parallel
  template:
    spec:
      containers:
      - name: vllm
        image: nvcr.io/nvidia/vllm:v0.6.3
        resources:
          limits:
            nvidia.com/gpu: 4  # tensor_parallelism = 4
        env:
        - name: TENSOR_PARALLEL_SIZE
          value: "4"
        - name: MODEL_NAME
          value: "llama-3-70b"
```

#### 3. **Creates Services**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: llama-3-70b
spec:
  clusterIP: None  # Headless
  selector:
    nvidia.com/dynamo-deployment: llama-3-70b
  ports:
  - port: 8000
```

#### 4. **Configures HPA**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: llama-3-70b-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: llama-3-70b
  minReplicas: 2
  maxReplicas: 100
  metrics:
  - type: External
    external:
      metric:
        name: dynamo_requests_per_second
      target:
        type: AverageValue
        averageValue: "50"
```

#### 5. **Monitors Performance**

The operator continuously:
- Measures actual latency and throughput
- Compares against SLA
- Scales up if SLA not met
- Scales down to save costs

#### 6. **Updates Status**

```yaml
status:
  phase: Running
  replicas: 4
  readyReplicas: 4
  conditions:
  - type: SLAMet
    status: "True"
    reason: AllMetricsWithinSLA
  currentMetrics:
    latencyMs: 45
    throughput: 120
    gpuUtilization: 75
```

## Key Innovations in Dynamo

### 1. **Tensor Parallelism Awareness**

Dynamo understands that models need to be sharded across GPUs:

```python
# Operator logic
if spec.placement.tensorParallelism > 1:
    # Each pod needs multiple GPUs
    resources = {
        'nvidia.com/gpu': spec.placement.tensorParallelism
    }
    # Set environment variables for vLLM
    env['TENSOR_PARALLEL_SIZE'] = spec.placement.tensorParallelism
    env['MASTER_ADDR'] = f"{name}-0.{service}"
```

### 2. **MIG (Multi-Instance GPU) Support**

Dynamo can slice GPUs for smaller models:

```yaml
spec:
  gpu:
    type: A100
    migProfile: mig-1g.5gb  # 1 GPU, 5GB memory
  scaling:
    maxReplicas: 20  # Can run 20 on one A100!
```

Operator creates:
```yaml
resources:
  limits:
    nvidia.com/mig-1g.5gb: 1
```

### 3. **SLA-Driven Autoscaling**

Unlike standard HPA (CPU-based), Dynamo scales based on:
- Requests per second
- Latency percentiles (p50, p95, p99)
- Queue depth
- Token generation rate

### 4. **Predictive Scaling**

Dynamo uses ML to predict:
- Traffic patterns
- Pre-provision resources before spikes
- Scale down before lulls

### 5. **Disaggregated Prefill/Decode**

For production LLM serving:

```yaml
spec:
  pipeline: Disaggregated
  prefill:
    replicas: 2
    gpuType: H100
  decode:
    replicas: 8
    gpuType: L40S  # Cheaper for decode
```

Operator creates two StatefulSets with different configs.

## Comparison: Simple vs Dynamo

| Feature | Our Example | NVIDIA Dynamo |
|---------|-------------|---------------|
| **CRD** | LLMModel | DynamoGraphDeployment |
| **Controller** | Simple Python | Complex Go operator |
| **Resources** | Deployment | StatefulSet + MIG + custom |
| **Scaling** | Manual | SLA-driven autoscaling |
| **Metrics** | CPU/memory | Latency, throughput, GPU |
| **GPU Awareness** | No | Yes (tensor parallelism, MIG) |
| **Prediction** | No | Yes (ML-based) |
| **Complexity** | ~50 lines | ~10,000+ lines |

## How to Learn From Dynamo

### Step 1: Understand the Pattern ✓
You've learned CRD + Operator basics!

### Step 2: Study Dynamo's CRDs

```bash
# If you have access to a Dynamo cluster
kubectl get crd | grep nvidia
kubectl describe crd dynamographdeployments.nvidia.com

# Look at example resources
kubectl get dynamographdeployments -o yaml
```

### Step 3: Build Your Own Simple Operator

Start with:
1. Define CRD for your use case
2. Write simple controller
3. Add reconciliation logic
4. Add status updates
5. Add metrics

### Step 4: Advanced Features

Add:
- Multiple reconcilers (for different resources)
- Metrics and observability
- Webhooks (validation/mutation)
- Finalizers (cleanup on delete)
- Leader election (HA operators)

## Open Source Alternatives

If you can't use Dynamo, check out:

### 1. **Ray Serve**
```yaml
apiVersion: ray.io/v1
kind: RayService
metadata:
  name: llm-serving
spec:
  serveConfig:
    import_path: serve.deployment
    runtime_env:
      pip: ["vllm", "transformers"]
```

### 2. **KServe**
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: llama-3-70b
spec:
  predictor:
    model:
      modelFormat:
        name: vllm
      storageUri: s3://models/llama-3-70b
```

### 3. **vLLM with K8s**
```yaml
apiVersion: apps/v1
kind: StatefulSet
spec:
  template:
    spec:
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        args:
        - --model=meta-llama/Llama-3-70b
        - --tensor-parallel-size=4
        resources:
          limits:
            nvidia.com/gpu: 4
```

## Next Steps

1. **Run the examples**: `./test-all-crd-operator.sh`
2. **Study the code**: Look at operator logic in `02-simple-operator.yaml`
3. **Experiment**: Modify the CRD or operator
4. **Build your own**: Use Kubebuilder to scaffold a real operator
5. **Dive deeper**: Read NVIDIA's blog posts and papers on Dynamo

## References

- [NVIDIA Dynamo Blog](https://developer.nvidia.com/blog/)
- [Kubernetes Operators](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
- [Kubebuilder](https://book.kubebuilder.io/)
- [Operator SDK](https://sdk.operatorframework.io/)
