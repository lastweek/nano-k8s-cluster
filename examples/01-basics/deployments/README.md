# Deployments Examples

This directory contains examples demonstrating Kubernetes Deployments - the primary way to manage stateless applications.

## Overview

A Deployment provides:
- **Declarative updates** - Describe desired state, K8s makes it happen
- **Self-healing** - Restarts crashed pods automatically
- **Scaling** - Easy scale up/down
- **Rolling updates** - Zero-downtime updates
- **Rollback** - Easy rollback to previous versions

## 🚀 Quick Start

### Option 1: Run All Examples

```bash
./test-all-deployments.sh
```

### Option 2: Run Individual Examples

```bash
# Run in learning order
./01-test-basic-deployment.sh
./02-test-scaling.sh
./03-test-rolling-update.sh
./04-test-update-strategies.sh
```

## Examples

| File | Description | Order | Test Script |
| ---- | ----------- | ----- | ------------ |
| [01-basic-deployment.yaml](01-basic-deployment.yaml) | Basic deployment with 3 replicas | 01 | [01-test-basic-deployment.sh](01-test-basic-deployment.sh) |
| [02-scaling.yaml](02-scaling.yaml) | Manual and autoscaling | 02 | [02-test-scaling.sh](02-test-scaling.sh) |
| [03-rolling-update.yaml](03-rolling-update.yaml) | Rolling update demonstration | 03 | [03-test-rolling-update.sh](03-test-rolling-update.sh) |
| [04-update-strategies.yaml](04-update-strategies.yaml) | Recreate vs RollingUpdate | 04 | [04-test-update-strategies.sh](04-test-update-strategies.sh) |

## What Each Test Script Demonstrates

1. ✅ Create deployment
2. ⏳ Watch rollout status
3. 📊 Show pods and replicasets
4. 🔄 Scale up/down
5. 🎲 Update image version
6. ↩️ Rollback if needed
7. 🧹 Cleanup

## Deployment vs Pod

| Feature | Pod | Deployment |
|---------|-----|------------|
| Self-healing | ❌ No | ✅ Yes |
| Scaling | ❌ Manual | ✅ Auto/Manual |
| Updates | ❌ Delete/recreate | ✅ Rolling updates |
| Rollback | ❌ Manual | ✅ Built-in |
| Use case | One-off tasks | Production apps |

## LLM Cluster Use Cases

| Use Case | Why Deployment? |
|----------|-----------------|
| LLM serving workers | Auto-restart on crashes |
| Prefill workers | Scale based on demand |
| Decode workers | Independent scaling |
| API gateways | Zero-downtime updates |

## Cleanup

```bash
./cleanup-all-deployments.sh
```

## Next Steps

- Learn [Services](../services/) for networking
- Learn [StatefulSets](../../04-stateful-apps/) for stateful apps
- Read [Deployments concept documentation](../../../docs/concepts/deployments.md)
