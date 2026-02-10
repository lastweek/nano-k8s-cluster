# Kubernetes LLM Cluster Examples

Examples and patterns for running LLM serving, training, and RL post-training on Kubernetes.

## Overview

This repository contains practical Kubernetes examples focused on building a production-grade LLM cluster that supports:

- **LLM Serving** - Disaggregated prefill/decode, KV-aware routing
- **LLM Training** - Distributed training with checkpoint/recovery
- **RL Post-Training** - RLHF with actor-critic architecture
- **Global Scheduler** - CPU-based request routing and policy management

## Quick Start

### Prerequisites

- Docker installed and running
- minikube (or any K8s cluster)
- kubectl CLI
- 16GB RAM available (for local minikube)

### Setup

```bash
# Clone the repository
git clone <repo-url>
cd nano-k8s-cluster

# Run setup script
./scripts/setup-minikube.sh

# Verify installation
./scripts/verify-setup.sh
```

### Run Your First Example

```bash
# Simple pod
kubectl apply -f examples/01-basics/pods/simple-pod.yaml

# Check it's running
kubectl get pods

# View logs
kubectl logs simple-pod

# Clean up
kubectl delete -f examples/01-basics/pods/simple-pod.yaml
```

### Run LLM Serving Example

```bash
# Deploy disaggregated LLM serving
kubectl apply -f examples/12-llm-cluster/serving/disaggregated-serving/

# Port forward to access
kubectl port-forward svc/llm-frontend 8000:8000

# Test the API
curl http://localhost:8000/v1/models

# Clean up
kubectl delete -f examples/12-llm-cluster/serving/disaggregated-serving/
```

## Contents

### 📚 Learn Kubernetes Basics

| Directory | Description | Examples |
|-----------|-------------|----------|
| [examples/01-basics/pods](examples/01-basics/pods/) | Container orchestration | Simple pods, multi-container, resources |
| [examples/01-basics/deployments](examples/01-basics/deployments/) | Stateless applications | Scaling, rolling updates, strategies |
| [examples/01-basics/services](examples/01-basics/services/) | Networking | ClusterIP, LoadBalancer, headless |
| [examples/02-config-secrets](examples/02-config-secrets/) | Configuration | ConfigMaps, Secrets |
| [examples/03-storage](examples/03-storage/) | Storage | PVCs, StorageClasses |
| [examples/04-stateful-apps](examples/04-stateful-apps/) | Stateful workloads | StatefulSets, distributed systems |
| [examples/05-health-monitoring](examples/05-health-monitoring/) | Health checks | Probes, monitoring |
| [examples/06-scaling](examples/06-scaling/) | Scaling | HPA, custom metrics |
| [examples/07-scheduling](examples/07-scheduling/) | Scheduling | Node selection, taints, affinity |
| [examples/08-networking](examples/08-networking/) | Advanced networking | Ingress, network policies |
| [examples/09-multitenancy](examples/09-multitenancy/) | Multi-tenancy | Namespaces, quotas, RBAC |

### 🚀 LLM Cluster Examples

| Directory | Description | Examples |
|-----------|-------------|----------|
| [examples/12-llm-cluster/serving](examples/12-llm-cluster/serving/) | LLM serving | Aggregated, disaggregated, multi-model |
| [examples/12-llm-cluster/training](examples/12-llm-cluster/training/) | Training jobs | Single-node, distributed, checkpoints |
| [examples/12-llm-cluster/rl-post-training](examples/12-llm-cluster/rl-post-training/) | RL post-training | RLHF, actor-critic, replay buffers |
| [examples/12-llm-cluster/full-cluster](examples/12-llm-cluster/full-cluster/) | Complete cluster | All components together |

### 🔧 Advanced Topics

| Directory | Description | Examples |
|-----------|-------------|----------|
| [examples/10-crd](examples/10-crd/) | Custom Resources | Define domain-specific APIs |
| [examples/11-operators](examples/11-operators/) | Operators | Build controllers for CRDs |
| [patterns](patterns/) | Reusable patterns | Sidecar, init containers, graceful shutdown |

## Documentation

- [Concepts](docs/concepts/) - Kubernetes concept explanations
- [LLM Patterns](docs/llm-patterns/) - LLM-specific patterns and best practices
- [Setup Guide](docs/setup.md) - Detailed environment setup
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions
- [Glossary](docs/glossary.md) - Kubernetes terminology

## Cheatsheets

- [kubectl Commands](Cheatsheets/kubectl.md) - Common kubectl commands
- [YAML Reference](Cheatsheets/yaml-reference.md) - YAML field reference
- [Common Commands](Cheatsheets/common-commands.md) - Quick reference

## Project Structure

```
nano-k8s-cluster/
├── examples/          # All Kubernetes examples
├── docs/             # Documentation
├── scripts/          # Utility scripts
├── Cheatsheets/      # Quick reference guides
├── docker/           # Dockerfiles for testing
├── helm-charts/      # Helm charts
├── patterns/         # Reusable patterns
└── tests/            # Integration tests
```

## Development Workflow

```bash
# Start minikube
minikube start --cpus=4 --memory=8192

# Work on examples
kubectl apply -f examples/<category>/<example>/

# Monitor resources
kubectl get all

# View logs
kubectl logs -f <pod-name>

# Clean up
./scripts/cleanup.sh
```

## Testing

```bash
# Run all integration tests
./tests/integration-tests/test-serving-cluster.sh

# Run load tests
cd tests/load-testing/locust-tests
locust -f llm-serving.py
```

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see LICENSE file for details

## Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [NVIDIA Dynamo](https://github.com/ai-dynamo/dynamo)
- [vLLM](https://github.com/vllm-project/vllm)
- [Kubebuilder](https://book.kubebuilder.io/)

## Status

🚧 **Work in Progress** - This repository is under active development. Examples are being added progressively.
