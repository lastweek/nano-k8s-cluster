# Model Warm-up Strategies

> Learn how to avoid cold-start issues in LLM serving with warm-up strategies and measure their impact.

---

## Table of Contents

1. [The Cold Start Problem](#the-cold-start-problem)
2. [Warm-up Strategies](#warm-up-strategies)
3. [Examples](#examples)
4. [Performance Benchmarking](#performance-benchmarking)
5. [Results Analysis](#results-analysis)
6. [Best Practices](#best-practices)

---

## The Cold Start Problem

### What is a Cold Start?

A **cold start** occurs when a new LLM serving pod receives its first request:

```
┌─────────────────────────────────────────────────────────────────┐
│  Without Warm-up (Cold Start)                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Pod Ready (container running)                              │  │
│  │         │                                                  │  │
│  │         ▼ (first request arrives)                          │  │
│  │         │                                                  │  │
│  │         ▼                                                  │  │
│  │  Load Model from Disk → GPU (30-120 seconds)              │  │
│  │         │                                                  │  │
│  │         ▼                                                  │  │
│  │  Process First Request                                    │  │
│  │         │                                                  │  │
│  │         ▼                                                  │  │
│  │  Return Response (user waited 60+ seconds!)               │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  With Warm-up (No Cold Start)                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Pod Created                                                │  │
│  │         │                                                  │  │
│  │         ▼                                                  │  │
│  │  Load Model from Disk → GPU (in background)               │  │
│  │         │                                                  │  │
│  │         ▼                                                  │  │
│  │  Send Warm-up Requests (validate model loaded)            │  │
│  │         │                                                  │  │
│  │         ▼                                                  │  │
│  │ Pod Ready (model actually loaded!)                        │  │
│  │         │                                                  │  │
│  │         ▼ (first request arrives)                          │  │
│  │  Process Immediately (user gets fast response!)           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Why Cold Starts Matter

| Impact | Without Warm-up | With Warm-up |
|--------|----------------|--------------|
| **First Request Latency** | 30-120 seconds | < 1 second |
| **User Experience** | Timeout/errors | Instant response |
| **Autoscaling** | Pods scale up but serve slowly | Pods ready immediately |
| **Cost Efficiency** | Over-provision to avoid cold starts | Scale based on actual demand |

### Real-World Impact

```bash
# Example: Scaling from 2 → 3 replicas
# Without warm-up:
kubectl scale deployment vllm --replicas=3
# Pods are "Ready" in 10 seconds...
# But first request to new pod takes 60 seconds!

# With warm-up:
kubectl scale deployment vllm --replicas=3
# Pods are "Ready" in 60 seconds...
# But first request takes < 1 second!
```

---

## Warm-up Strategies

### Strategy 1: Readiness Probe Warm-up

**Use Kubernetes readiness probes to ensure the model is actually loaded.**

```yaml
readinessProbe:
  httpGet:
    path: /health       # Endpoint that checks model is loaded
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 30   # Wait up to 150 seconds for model to load
```

**How it works:**
1. Pod container starts
2. vLLM loads model in background
3. Readiness probe checks `/health` endpoint
4. `/health` returns 200 OK only when model is loaded
5. Pod marked "Ready" → traffic starts flowing

**Pros:** Simple, no extra components
**Cons:** Pod takes longer to be "Ready"

---

### Strategy 2: Init Container Warm-up

**Use an init container to pre-warm the model before the main container starts.**

```yaml
initContainers:
  - name: model-warmup
    image: vllm/vllm-openai:latest
    command: ["python", "-c", """
        import requests
        import time
        # Wait for model to load
        while True:
            try:
                r = requests.get('http://localhost:8000/health')
                if r.json().get('model_loaded'):
                    break
            except:
                pass
            time.sleep(2)
        # Send warm-up inference
        requests.post('http://localhost:8000/v1/completions', json={
            'model': 'meta-llama/Llama-3-70B',
            'prompt': 'Warm-up',
            'max_tokens': 1
        })
    """]
```

**Pros:** Warm-up happens before pod is "Ready"
**Cons:** More complex, init container has resource overhead

---

### Strategy 3: Staged Rollout

**Gradually scale up and warm pods before they're needed.**

```yaml
# Pre-scale during low-traffic periods
apiVersion: batch/v1
kind: CronJob
metadata:
  name: morning-warmup
spec:
  schedule: "0 8 * * *"  # 8 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: scaler
            image: bitnami/kubectl
            command:
            - /bin/sh
            - -c
            - |
              # Scale up 30 minutes before peak traffic
              kubectl scale deployment vllm --replicas=10
              # Wait for all pods to be ready
              kubectl wait --for=condition=available deployment/vllm --timeout=300s
```

**Pros:** Predictable scaling, no surprise cold starts
**Cons:** Less responsive to sudden traffic spikes

---

### Strategy 4: Warm-up Sidecar

**A dedicated sidecar that continuously sends warm-up requests.**

```yaml
spec:
  containers:
  - name: vllm
    image: vllm/vllm-openai:latest
  - name: warmup-sidecar
    image: python:3.11
    command: ["python", "-m", "warmup_client"]
```

**Pros:** Continuous warm-up, can re-warm after model unload
**Cons:** Extra resource usage

---

### Strategy 5: Model Caching

**Pre-load models on PVs or use daemonsets for persistent model cache.**

```yaml
# DaemonSet ensures models are pre-loaded on all nodes
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: model-cacher
spec:
  selector:
    matchLabels:
      app: model-cacher
  template:
    spec:
      containers:
      - name: cacher
        image: vllm/vllm-openai:latest
        command: ["python", "-c", """
            # Download and cache models to shared PV
            from huggingface_hub import snapshot_download
            snapshot_download('meta-llama/Llama-3-70B')
            # Keep container alive to maintain cache
            while True:
                time.sleep(3600)
        """]
        volumeMounts:
        - name: model-cache
          mountPath: /models
      volumes:
      - name: model-cache
        hostPath:
          path: /var/lib/vllm/models  # Shared across pods
```

**Pros:** Fastest cold start (model already on disk)
**Cons:** Storage overhead, models may not be in GPU memory

---

## Examples

### Example Structure

```
16-model-warmup/
├── 01-no-warmup.yaml              # Baseline: no warm-up strategy
├── 02-readiness-probe-warmup.yaml # Strategy 1: Readiness probe
├── 03-init-container-warmup.yaml  # Strategy 2: Init container
├── 04-staged-rollout-warmup.yaml  # Strategy 3: CronJob pre-scaling
├── 05-model-cache-daemonset.yaml  # Strategy 5: Model caching
├── benchmark.sh                   # Performance testing script
├── warmup-client.py               # Helper for warm-up requests
├── docker/
│   ├── Dockerfile.vllm-sim       # Simulated vLLM with warm-up
│   └── app.py                    # Test application
└── README.md
```

---

## Performance Benchmarking

### Running the Benchmark

```bash
# 1. Build the test application
cd docker
docker build -t vllm-warmup-test:latest -f Dockerfile.vllm-sim .

# 2. Apply the deployment (choose one)
kubectl apply -f 01-no-warmup.yaml              # Baseline
kubectl apply -f 02-readiness-probe-warmup.yaml # Readiness probe

# 3. Run the benchmark
./benchmark.sh

# 4. Compare results
cat results/baseline-*.txt
cat results/warmup-*.txt
```

### What the Benchmark Tests

| Metric | Description | Command |
|--------|-------------|---------|
| **Pod Start Time** | Time from pod creation to container running | `kubectl get pods` |
| **Time to Ready** | Time from pod creation to pod "Ready" | `kubectl wait` |
| **Time to First Token** | Latency of first request after pod ready | `curl` latency |
| **Time to Second Token** | Latency of second request (warm cache) | `curl` latency |
| **Memory Usage** | GPU memory usage during warm-up | `nvidia-smi` |

---

## Results Analysis

### Expected Results

```
┌─────────────────────────────────────────────────────────────────┐
│  Cold Start Comparison (Llama-3-70B on 4x A100)                 │
├─────────────────────────────────────────────────────────────────┤
│  Strategy              │ Pod Ready │ First Req │ Total Latency │
├─────────────────────────────────────────────────────────────────┤
│  No Warm-up            │     8s    │    45s    │     53s       │
│  Readiness Probe       │    48s    │     2s    │     50s       │
│  Init Container        │    52s    │     1s    │     53s       │
│  Model Cache (disk)    │    10s    │    25s    │     35s       │
│  Model Cache (GPU)     │    50s    │     1s    │     51s       │
└─────────────────────────────────────────────────────────────────┘

Key Insights:
- "No Warm-up" has fastest pod ready time, but slowest first request
- "Readiness Probe" delays pod ready, but first request is fast
- "Model Cache (disk)" reduces GPU loading time from 45s → 25s
```

### Why Readiness Probe Wins

```
User Experience:

No Warm-up:
  Pod Ready (8s) → User Request → 45s loading → Response (53s total)
                ↑
                User thinks pod is ready, but it's not!

Readiness Probe:
  Pod Ready (48s, model actually loaded) → User Request → Response (49s total)
                                        ↑
                                        User waits, but gets instant response
```

**The key insight:** Users don't care when the pod is "Ready" — they care about request latency!

---

## Best Practices

### When to Use Each Strategy

| Scenario | Best Strategy | Why |
|----------|---------------|-----|
| **Production API** | Readiness Probe | Guarantees model loaded before traffic |
| **Low-latency requirements** | Model Cache (GPU) | Model stays in GPU memory |
| **Cost optimization** | Staged Rollout | Scale up before traffic, scale down after |
| **Multi-model serving** | Model Cache (disk) | Shared cache reduces storage |
| **Burst traffic** | Over-provision + Readiness Probe | Buffer capacity for spikes |

### General Recommendations

1. **Always use readiness probes that check model status**
   - Don't just check HTTP 200
   - Verify model is actually loaded
   - Check KV cache is initialized

2. **Measure your actual cold start times**
   - Model loading varies by size
   - GPU type affects loading speed
   - Network storage can be slow

3. **Consider model size**
   - Small models (< 7B): Cold start ~10-20s
   - Medium models (7B-30B): Cold start ~30-60s
   - Large models (> 70B): Cold start ~60-120s

4. **Set appropriate timeouts**
   ```yaml
   readinessProbe:
     failureThreshold: 30   # 30 * 5s = 150s timeout
   ```

5. **Monitor warm-up success**
   - Alert on warm-up failures
   - Track readiness probe failures
   - Monitor first-request latency

---

## Troubleshooting

### Issue: Pods stuck in "NotReady"

```bash
# Check readiness probe logs
kubectl logs <pod> -c warmup-container

# Describe pod to see probe failures
kubectl describe pod <pod>

# Increase timeout if needed
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"vllm","readinessProbe":{"failureThreshold":60}}]}}}}'
```

### Issue: Warm-up requests failing

```bash
# Check if model is actually loading
kubectl logs <pod> | grep -i "loading model"

# Verify health endpoint
kubectl exec <pod> -- curl http://localhost:8000/health

# Check GPU memory
kubectl exec <pod> -- nvidia-smi
```

### Issue: Model cache not working

```bash
# Check if PV is mounted
kubectl exec <pod> -- df -h | grep models

# Verify cache directory permissions
kubectl exec <pod> -- ls -la /models

# Check if daemonset is running
kubectl get pods -l app=model-cacher
```

---

## Further Reading

- [Kubernetes Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [vLLM Model Loading](https://docs.vllm.ai/en/latest/serving/deployment.html)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Startup Probes for Slow Startups](https://kubernetes.io/docs/tasks/configure-pod-container/configure-startup-probe/)
