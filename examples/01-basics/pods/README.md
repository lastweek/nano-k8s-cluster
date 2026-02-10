# Pods Examples

This directory contains examples demonstrating Kubernetes Pods - the smallest deployable unit in Kubernetes.

## Overview

A Pod encapsulates one or more containers with shared network and storage. This is the fundamental building block for Kubernetes applications.

## 🚀 Quick Start

### Option 1: Run All Examples Automatically

```bash
# Run all pod examples with automated tests
./test-all-pods.sh
```

### Option 2: Run Individual Examples

Each example has its own test script that demonstrates the concept:

```bash
# Test individual examples (in order)
./01-test-simple-pod.sh
./02-test-multi-container-pod.sh
./03-test-pod-with-resources.sh
./04-test-pod-with-probes.sh
./05-test-pod-with-env.sh
./06-test-pod-with-init-container.sh
```

### Option 3: Manual Testing

```bash
# Apply example
kubectl apply -f 01-simple-pod.yaml

# Check status
kubectl get pods

# View logs
kubectl logs simple-pod

# Delete
kubectl delete -f 01-simple-pod.yaml
```

## Examples

| File | Description | Order | Test Script |
| ---- | ----------- | ----- | ------------ |
| [01-simple-pod.yaml](01-simple-pod.yaml) | Basic single-container pod | 01 | [01-test-simple-pod.sh](01-test-simple-pod.sh) |
| [02-multi-container-pod.yaml](02-multi-container-pod.yaml) | Pod with multiple containers (sidecar pattern) | 02 | [02-test-multi-container-pod.sh](02-test-multi-container-pod.sh) |
| [03-pod-with-resources.yaml](03-pod-with-resources.yaml) | Pod with CPU/memory limits | 03 | [03-test-pod-with-resources.sh](03-test-pod-with-resources.sh) |
| [04-pod-with-probes.yaml](04-pod-with-probes.yaml) | Pod with health checks | 04 | [04-test-pod-with-probes.sh](04-test-pod-with-probes.sh) |
| [05-pod-with-env.yaml](05-pod-with-env.yaml) | Pod with environment variables | 05 | [05-test-pod-with-env.sh](05-test-pod-with-env.sh) |
| [06-pod-with-init-container.yaml](06-pod-with-init-container.yaml) | Pod with init container | 06 | [06-test-pod-with-init-container.sh](06-test-pod-with-init-container.sh) |

## What Each Test Script Does

Each test script:
1. ✅ Applies the pod manifest
2. ⏳ Waits for the pod to be ready
3. 📊 Shows pod status and details
4. 📝 Displays relevant logs
5. 🧪 Tests the pod's functionality
6. 📚 Explains the key concepts
7. 🧹 Provides cleanup instructions

## Cleanup

```bash
# Clean up all pod examples
./cleanup-all-pods.sh

# Or clean up individual examples
kubectl delete -f 01-simple-pod.yaml
```

## Use Cases

### LLM Cluster Examples

| Use Case | Example File |
|----------|--------------|
| LLM serving with monitoring | [02-multi-container-pod.yaml](02-multi-container-pod.yaml) |
| LLM server with resource limits | [03-pod-with-resources.yaml](03-pod-with-resources.yaml) |
| LLM with slow model loading | [04-pod-with-probes.yaml](04-pod-with-probes.yaml) |
| Model pre-loading before serving | [06-pod-with-init-container.yaml](06-pod-with-init-container.yaml) |

## Common Patterns

### Sidecar Pattern
Main application + helper container in same Pod:
- Application logs → Log shipper sidecar
- Application metrics → Monitoring sidecar
- Application + local proxy

### Init Container Pattern
Setup tasks before main container starts:
- Download models from S3/HuggingFace
- Generate configuration files
- Wait for dependencies to be ready

### Multi-Container Pod Benefits
- Shared localhost communication
- Shared storage volumes
- Atomic deployment (always together)
- Easier debugging

## Troubleshooting

### Pod stuck in Pending
```bash
kubectl describe pod <pod-name>
# Check events section for reasons
```

### Container crash looping
```bash
kubectl logs <pod-name> --previous
# See logs from previous container attempt
```

### Can't connect to Pod
```bash
# Port forward to access locally
kubectl port-forward <pod-name> 8080:80

# Exec into pod for debugging
kubectl exec -it <pod-name> -- sh
```

## Next Steps

- Learn [Deployments](../deployments/) for self-healing and scaling
- Learn [Services](../services/) for networking
- Read [Pods concept documentation](../../../docs/concepts/pods.md)

## Cleanup

```bash
# Delete all pods in this directory
kubectl delete -f .

# Or use the cleanup script
cd ../../..
./scripts/cleanup.sh
```
