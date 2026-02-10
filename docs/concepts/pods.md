# Pods

## Overview

A **Pod** is the smallest deployable unit in Kubernetes. It represents a single instance of a running process in your cluster.

## Key Concepts

### What is a Pod?

- A Pod encapsulates one or more containers
- Containers in a Pod share the same network namespace (same IP, port space)
- Containers in a Pod can communicate using `localhost`
- Containers in a Pod share storage volumes

### Single Container Pods

Most commonly, a Pod contains just one container:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
```

### Multi-Container Pods

Pods can contain multiple containers that work together:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: llm-with-monitoring
spec:
  containers:
  - name: llm-server
    image: vllm/vllm:latest
    ports:
    - containerPort: 8000
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log

  - name: log-shipper
    image: fluent/fluent-bit:latest
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log

  volumes:
  - name: shared-logs
    emptyDir: {}
```

### Common Sidecar Patterns

| Pattern | Use Case | Example |
|---------|----------|---------|
| **Log shipper** | Centralized logging | Fluentd, Filebeat |
| **Monitoring agent** | Metrics collection | Prometheus exporter |
| **Init container** | Setup tasks | Download models, config generation |
| **Proxy** | Network routing | Envoy, Istio sidecar |

## Pod Lifecycle

```
Pending → Running → Succeeded/Failed
   ↓
   ContainerCreating
```

### Phases

| Phase | Description |
|-------|-------------|
| `Pending` | Pod accepted, containers not created yet |
| `Running` | At least one container is running |
| `Succeeded` | All containers terminated successfully |
| `Failed` | At least one container terminated in error |
| `Unknown` | State of pod couldn't be obtained |

## Common Fields

### Resources

```yaml
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

- `requests`: Guaranteed resources (scheduling)
- `limits`: Maximum resources (throttling/eviction)

### Probes

```yaml
spec:
  containers:
  - name: app
    image: nginx
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 3
      periodSeconds: 3
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 3
      periodSeconds: 3
```

| Probe Type | Purpose | Failure Action |
|------------|---------|----------------|
| **Liveness** | Detect hangs | Restart container |
| **Readiness** | Traffic routing | Stop sending traffic |
| **Startup** | Slow-starting apps | Give more time |

### Environment Variables

```yaml
spec:
  containers:
  - name: app
    image: nginx
    env:
    - name: MODEL_NAME
      value: "llama-70b"
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: api-secret
          key: key
    envFrom:
    - configMapRef:
        name: app-config
```

## Common Commands

```bash
# Create a pod
kubectl apply -f pod.yaml

# List pods
kubectl get pods

# Get detailed information
kubectl describe pod <pod-name>

# View logs
kubectl logs <pod-name>

# View logs for multi-container pod
kubectl logs <pod-name> -c <container-name>

# Execute command in pod
kubectl exec -it <pod-name> -- sh

# Delete pod
kubectl delete pod <pod-name>

# Port forward to pod
kubectl port-forward <pod-name> 8080:80
```

## When to Use Pods Directly

### ✅ Use Pods When:
- Debugging or testing
- One-off tasks
- Learning Kubernetes basics

### ❌ Don't Use Pods When:
- You need scalability → Use **Deployment**
- You need stable identity → Use **StatefulSet**
- You need self-healing → Use **Deployment**

## LLM Cluster Use Cases

| Component | Pod Pattern | Reason |
|-----------|-------------|--------|
| LLM serving container | Single container with monitoring sidecar | Log shipping |
| Model loading | Init container + main container | Pre-download models |
| Training worker | Single container with shared volume | Checkpoint access |

## Related Resources

- [Deployments](deployments.md) - For managing replicated Pods
- [Services](services.md) - For networking Pods
- [StatefulSets](statefulsets.md) - For stateful Pods
- [Examples](../../examples/01-basics/pods/) - Working examples
