# Horizontal Pod Autoscaler (HPA) Examples

This section covers Kubernetes Horizontal Pod Autoscaler - automatically scaling pods based on metrics.

## Prerequisites

- Kubernetes cluster running (minikube, kind, or k3s)
- kubectl configured and working
- **metrics-server must be installed**

### Install metrics-server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify installation
kubectl get deployment metrics-server -n kube-system
```

## Learning Objectives

After completing these examples, you will understand:

1. **HPA Basics**: CPU and memory-based autoscaling
2. **Resource Requirements**: Requests required for HPA
3. **Scaling Behavior**: Stabilization windows and scaling policies
4. **Custom Metrics**: Scaling based on application metrics

## Examples

### 01: Basic HPA (CPU/Memory)

**File**: [01-hpa-basic.yaml](01-hpa-basic.yaml)

Learn:
- HPA based on CPU and memory utilization
- Resource requests are required
- Stabilization windows for scale down
- Scaling policies

**Run**:
```bash
./01-test-hpa-basic.sh
```

**Key concepts**:
- HPA adjusts replica count based on metrics
- CPU/memory requests required for autoscaling
- Scale up happens immediately
- Scale down has stabilization window (default 5 minutes)

**HPA Configuration**:
```yaml
minReplicas: 2   # Minimum pods
maxReplicas: 10  # Maximum pods
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50  # Target 50% CPU
```

**Scaling Calculation**:
```
Desired Replicas = (Current Metric / Target) * Current Replicas

Example:
- Current pods: 2
- CPU request: 100m
- Current CPU: 180m (90% of request)
- Target: 50%
- Desired = (180m / 50%) / 100m = 3.6 → 4 pods
```

**For LLM Serving**:
- Scale based on request queue length (custom metric)
- Scale based on GPU utilization (custom metric)
- Scale based on requests per second
- Minimum pods for baseline load
- Maximum pods limited by GPU availability

---

## HPA Metrics Types

### Resource Metrics (Built-in)
| Metric | Description | Example Target |
|--------|-------------|----------------|
| CPU | Percentage of requested CPU | 50% utilization |
| Memory | Percentage of requested memory | 80% utilization |

### Custom Metrics (require adapter)
| Metric | Description | Use Case |
|--------|-------------|----------|
| Requests per second | Application-level QPS | Web/API servers |
| Queue length | Request queue depth | Message consumers |
| GPU utilization | GPU usage percentage | ML model serving |
| Custom business metrics | Any metric exposed by app | Domain-specific |

## Running All Examples

Run all HPA examples sequentially:

```bash
./test-all-scaling-hpa.sh
```

## Cleanup

Clean up all HPA examples:

```bash
./cleanup-all-scaling-hpa.sh
```

Or clean up individual examples:

```bash
kubectl delete -f 01-hpa-basic.yaml
```

## Common Commands

```bash
# List HPAs
kubectl get hpa

# Describe HPA
kubectl describe hpa <hpa-name>

# Get HPA YAML
kubectl get hpa <hpa-name> -o yaml

# Edit HPA
kubectl edit hpa <hpa-name>

# Auto-scale a deployment
kubectl autoscale deployment nginx --cpu-percent=50 --min=2 --max=10

# Get current metrics
kubectl top pods
kubectl top nodes
```

## HPA Behavior Configuration

Control how quickly HPA scales up/down:

```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300  # Wait before scaling down
    policies:
    - type: Percent
      value: 50  # Max 50% reduction
      periodSeconds: 60
  scaleUp:
    stabilizationWindowSeconds: 0  # Scale up immediately
    policies:
    - type: Percent
      value: 100  # Can double pods
      periodSeconds: 30
```

**Best practices**:
- Set stabilization window to avoid flapping
- Use percent policies for large scales
- Use pods policies for small scales
- Set both percent and pods policies with `selectPolicy: Max`

## HPA vs Other Scaling Options

| Scaling Type | What | When |
|--------------|-------|------|
| HPA | Scale pods horizontally | Variable workload |
| VPA | Scale pod resources vertically | Right-sizing resources |
| Cluster Autoscaler | Scale cluster nodes | Need more nodes |
| KEDA | Event-driven scaling | Kafka, RabbitMQ, etc. |

## Architecture: HPA in LLM Serving

```
┌─────────────────────────────────────────────────────────┐
│                     HPA Controller                       │
│  ┌───────────────────────────────────────────────────┐  │
│  │  - Checks metrics every 15 seconds                │  │
│  │  - Calculates desired replica count                │  │
│  │  - Updates deployment replica count                 │  │
│  └───────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                   Deployment (Model Server)              │
│                                                          │
│   ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐             │
│   │Pod-1│ │Pod-2│ │Pod-3│ │Pod-4│ │Pod-5│  ...         │
│   │25%  │ │30%  │ │45%  │ │60%  │ │80%  │              │
│   └─────┘ └─────┘ └─────┘ └─────┘ └─────┘              │
│                                                          │
│   Average: 48% → Target: 50% ✓                           │
│   Scale down to 4 pods                                   │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                     Metrics Server                        │
│  - Reports CPU/memory usage from all pods                │
│  - Required for HPA to function                          │
└─────────────────────────────────────────────────────────┘
```

## Custom Metrics with Prometheus Adapter

For advanced LLM serving scenarios, use custom metrics:

### Setup Prometheus Adapter

```bash
helm install prometheus-adapter kube-prometheus-stack/prometheus-adapter
```

### HPA with Custom Metrics

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: llm-serving-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llm-serving
  minReplicas: 2
  maxReplicas: 10
  metrics:
  # Scale based on requests per second
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
  # Scale based on GPU utilization
  - type: External
    external:
      metric:
        name: gpu_utilization_percent
      target:
        type: AverageValue
        averageValue: "80"
```

## Best Practices

1. **Always set resource requests** - Required for CPU/memory HPA
2. **Set appropriate min/max** - Balance cost vs availability
3. **Use stabilization windows** - Prevent scaling flapping
4. **Monitor HPA events** - `kubectl describe hpa`
5. **Test scaling behavior** - Load test before production
6. **Consider custom metrics** - For application-level scaling
7. **Set alerts** - For hitting max/min replica limits

## Troubleshooting

### HPA not scaling

```bash
# Check metrics server
kubectl get deployment metrics-server -n kube-system

# Check pod metrics
kubectl top pods

# Describe HPA
kubectl describe hpa <name>

# Check conditions
kubectl get hpa <name> -o jsonpath='{.status.conditions}'
```

### Metrics not available

```bash
# Check metrics server logs
kubectl logs -n kube-system deployment/metrics-server

# Common issue: metrics-server can't see pods
# Fix: Add --kubelet-use-node-status-port
kubectl edit deployment metrics-server -n kube-system
```

### HPA stuck at min/max

```bash
# Check if hitting min/max
kubectl get hpa <name> -o jsonpath='{.status.desiredReplicas}'

# Adjust min/max
kubectl edit hpa <name>
```

## Next Steps

After mastering HPA:
1. **Vertical Pod Autoscaler (VPA)** - Auto-size pod resources
2. **Cluster Autoscaler** - Auto-scale cluster nodes
3. **KEDA** - Event-driven autoscaling
4. **Advanced Metrics** - Prometheus adapter, custom metrics

## References

- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [HPA V2 API](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.27/#horizontalpodautoscaler-v2-autoscaling)
