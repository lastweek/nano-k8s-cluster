# CRDs and Operators Examples

This section covers Kubernetes Custom Resource Definitions (CRDs) and Operators - the pattern used by NVIDIA Dynamo and other advanced Kubernetes platforms.

## Prerequisites

- Kubernetes cluster running (minikube, kind, or k3s)
- kubectl configured and working
- Completed all previous sections (Pods, Deployments, Services, StatefulSets)

## Learning Objectives

After completing these examples, you will understand:

1. **CRDs**: Extend Kubernetes API with custom resources
2. **Operators**: Controllers that watch and reconcile custom resources
3. **Reconciliation Loop**: The heart of operator pattern
4. **Real-world Examples**: How NVIDIA Dynamo, Cert-Manager, etc. work

## What Are CRDs and Operators?

### CRD (Custom Resource Definition)

A CRD extends Kubernetes with your own custom resources. Think of it as adding a new "kind" to Kubernetes.

**Example**: Instead of just Deployment, Service, Pod, you can have:
- `ModelDeployment` for deploying LLMs
- `TrainingJob` for distributed training
- `Certificate` for TLS certificates (Cert-Manager)
- `Prometheus` for monitoring (Prometheus Operator)

### Operator

An operator is a controller that:
1. **Watches** your custom resources
2. **Reconciles** desired state (what you want) with actual state (what exists)
3. **Automates** complex tasks

**The Pattern**:
```
You declare what you want (YAML) → Operator makes it happen
```

## Examples

### 01: What is a CRD?

**File**: [01-what-is-crd.yaml](01-what-is-crd.yaml)

Learn:
- How to define a custom resource (LLMModel)
- CRD schema and validation
- Using kubectl with custom resources
- CRD alone doesn't DO anything (need operator)

**Run**:
```bash
./01-test-crd.sh
```

**Key concepts**:
- CRD extends Kubernetes API
- Define schema with OpenAPI v3
- Use kubectl to manage custom resources
- CRD is just the definition (like a class)

**Example CRD**:
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: llmmodels.ai.example.com
spec:
  group: ai.example.com
  names:
    plural: llmmodels
    singular: llmmodel
    kind: LLMModel
  scope: Namespaced
  versions:
  - name: v1
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            properties:
              modelName:
                type: string
              replicas:
                type: integer
```

**Usage**:
```bash
kubectl get llmmodels
kubectl describe llmmodel my-model
kubectl apply -f my-llm-model.yaml
```

---

### 02: Simple Operator

**File**: [02-simple-operator.yaml](02-simple-operator.yaml)

Learn:
- Operator watches custom resources
- Reconciliation loop
- Creates deployments from LLMModel specs
- Updates status based on actual state

**Run**:
```bash
./02-test-operator.sh
```

**Key concepts**:
- Controller watches resources (via Kubernetes watch API)
- Reconciliation: desired vs actual state
- Operator creates/updates deployments automatically
- Status updated continuously

**The Control Loop**:
```python
while True:
    desired = get_llmmodel_spec()      # What you want
    actual = get_deployment_status()    # What exists

    if desired != actual:
        reconcile()                     # Fix it!

    sleep()
```

**Architecture**:
```
┌─────────────────────────────────────────────────────────────┐
│  You declare desired state                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ apiVersion: ai.example.com/v1                          │  │
│  │ kind: LLMModel                                         │  │
│  │ metadata:                                               │  │
│  │   name: llama-3-70b                                    │  │
│  │ spec:                                                   │  │
│  │   replicas: 3                                          │  │
│  │   gpuType: H100                                         │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Operator (Controller)                                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 1. Watch LLMModel resources                           │  │
│  │ 2. Get spec (desired state)                           │  │
│  │ 3. Get deployment (actual state)                      │  │
│  │ 4. If different, reconcile:                           │  │
│  │    - Create/update deployment                         │  │
│  │    - Update status                                    │  │
│  │ 5. Repeat forever                                     │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Actual State (Deployment, Pods, Services)                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Running All Examples

Run all CRD and Operator examples sequentially:

```bash
./test-all-crd-operator.sh
```

## Cleanup

Clean up all CRD and Operator examples:

```bash
./cleanup-all-crd-operator.sh
```

## CRD vs Operator

| Aspect | CRD | Operator |
|--------|-----|----------|
| **Purpose** | Define custom API | Watch and reconcile |
| **Like** | Class in OOP | Instance method in OOP |
| **Does it DO anything?** | No (just schema) | Yes (takes action) |
| **Example** | LLMModel definition | Creates deployments |
| **Together** | API specification | Automation logic |

## Common Commands

### CRD Commands
```bash
# List CRDs
kubectl get crds

# Describe CRD
kubectl describe crd <crd-name>

# Get CRD YAML
kubectl get crd <crd-name> -o yaml

# Delete CRD (also deletes all instances!)
kubectl delete crd <crd-name>
```

### Custom Resource Commands
```bash
# List custom resources
kubectl get llmmodels
kubectl get llm  # using short name

# Describe custom resource
kubectl describe llmmodel <name>

# Get YAML
kubectl get llmmodel <name> -o yaml

# Create from file
kubectl apply -f my-llm-model.yaml

# Edit resource
kubectl edit llmmodel <name>

# Delete resource
kubectl delete llmmodel <name>
```

## Real-World Examples

### Cert-Manager
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-cert
spec:
  secretName: my-tls-cert
  issuerRef:
    name: letsencrypt-prod
  dnsNames:
  - api.example.com

# Operator automatically:
# - Requests certificate from Let's Encrypt
# - Creates secret with certificate
# - Renews before expiry
```

### Prometheus Operator
```yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prometheus
spec:
  replicas: 2
  resources:
    requests:
      memory: 400Mi

# Operator automatically:
# - Deploys Prometheus
# - Configures scrape targets
# - Manages storage
```

### NVIDIA Dynamo
```yaml
apiVersion: nvidia.com/v1
kind: DynamoGraphDeployment
metadata:
  name: llama-3-70b
spec:
  sla:
    max_latency_ms: 100
    min_throughput: 50
  model:
    name: llama-3-70b
    placement:
      tensor_parallel_size: 4
      gpu_type: H100

# Operator automatically:
# - Deploys model across GPUs
# - Scales based on SLA
# - Manages model lifecycle
```

## Building Your Own Operator

### Step 1: Define CRD
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: myresources.example.com
spec:
  group: example.com
  names:
    kind: MyResource
  versions:
  - name: v1
    schema:
      openAPIV3Schema:
        # Your schema here
```

### Step 2: Write Controller
```python
from kubernetes import client, config
from kubernetes.watch import Watch

def reconcile(resource):
    # Get desired state from resource spec
    # Get actual state from cluster
    # Make them match

def watch():
    w = Watch()
    for event in w.stream(...):
        reconcile(event['object'])
```

### Step 3: Deploy Operator
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: operator
        image: my-operator:latest
```

### Operator Frameworks

Instead of writing from scratch, use:
- **Kubebuilder** - https://book.kubebuilder.io/
- **Operator SDK** - https://sdk.operatorframework.io/
- **KUDO** - https://kudo.dev/

These generate boilerplate and handle:
- Watch API
- Reconciliation loop
- CRD generation
- RBAC setup

## Best Practices

1. **Idempotent** - Reconcile should be safe to run multiple times
2. **Finalizers** - Use for cleanup before deletion
3. **Status** - Update status, don't modify spec
4. **Logging** - Log reconciliation decisions
5. **Metrics** - Expose Prometheus metrics
6. **Labels** - Use labels for owner references
7. **RBAC** - Principle of least privilege
8. **Testing** - Test with envtest

## Architecture: Operator in LLM Serving

```
┌───────────────────────────────────────────────────────────┐
│                    User (kubectl apply)                   │
└───────────────────────────┬───────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────┐
│  CRD: ModelDeployment                                     │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ spec:                                                │  │
│  │   model: llama-3-70b                                │  │
│  │   replicas: 4                                       │  │
│  │   sla.maxLatency: 100ms                             │  │
│  └─────────────────────────────────────────────────────┘  │
└───────────────────────────┬───────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────┐
│  ModelDeployment Operator                                 │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Reconciliation Loop:                                 │  │
│  │ 1. Read ModelDeployment spec                        │  │
│  │ 2. Calculate needed replicas (based on SLA)        │  │
│  │ 3. Create/Update StatefulSet (for stable identity)│  │
│  │ 4. Create Service for discovery                     │  │
│  │ 5. Create HPA for autoscaling                       │  │
│  │ 6. Update status                                    │  │
│  └─────────────────────────────────────────────────────┘  │
└───────────────────────────┬───────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────┐
│  Kubernetes Resources (Managed by Operator)               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │StatefulSet│  │ Service  │  │   HPA    │  │ ConfigMap│ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘ │
│         │
│         ▼
│  ┌─────────────────────────────────────────────────────┐
│  │ Pods (llama-3-70b-0, llama-3-70b-1, ...)          │
│  └─────────────────────────────────────────────────────┘
└───────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Operator not creating resources

```bash
# Check operator is running
kubectl get pods -l app=llm-operator

# Check operator logs
kubectl logs -l app=llm-operator

# Check RBAC
kubectl auth can-i create deployments --as=system:serviceaccount:default:llm-operator

# Describe custom resource
kubectl describe llmmodel my-model
```

### Status not updating

```bash
# Check operator has permission for /status
kubectl get role llm-operator -o yaml

# Check if status subresource is enabled
kubectl get crd llmmodels.ai.example.com -o jsonpath='{.spec.versions[0].subresources}'
```

### Reconciliation loop stuck

```bash
# Check operator logs for errors
kubectl logs -l app=llm-operator --tail=100

# Check events
kubectl get events --sort-by='.lastTimestamp' | tail -20

# Enable debug logging
kubectl set env deployment/llm-operator LOG_LEVEL=debug
```

## Next Steps

After mastering CRDs and Operators:
1. **Kubebuilder** - Scaffold operators quickly
2. **Operator Patterns** - Advanced reconciliation patterns
3. **Helm Charts** - Package your operators
4. **OAM** - Open Application Model
5. **Building a production operator** - Monitoring, metrics, testing

## References

- [Kubernetes CRD Documentation](https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/)
- [Kubebuilder Book](https://book.kubebuilder.io/)
- [Operator SDK](https://sdk.operatorframework.io/)
- [Operator Patterns](https://github.com/operator-framework/patterns)
- [NVIDIA Blog on Operators](https://developer.nvidia.com/blog/)
