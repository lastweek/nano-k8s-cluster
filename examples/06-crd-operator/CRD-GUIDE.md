# CRD Deep Dive Guide

> A clear, step-by-step guide to understanding Custom Resource Definitions and how they create containers.

---

## Table of Contents

1. [The Big Question: How do CRDs create containers?](#the-big-question)
2. [Understanding the Three Layers](#understanding-the-three-layers)
3. [Step-by-Step: From CRD to Running Container](#step-by-step-from-crd-to-running-container)
4. [The Reconciliation Loop Explained](#the-reconciliation-loop-explained)
5. [Practical Examples](#practical-examples)
6. [Common Confusions Clarified](#common-confusions-clarified)

---

## The Big Question: How do CRDs create containers?

**Short answer**: CRDs do NOT create containers directly.

**Long answer**: A CRD defines a custom API resource. An **Operator** (controller) watches that resource and creates the actual containers (via Deployments, StatefulSets, etc.).

---

## Understanding the Three Layers

Think of CRDs + Operators as a three-layer system:

```
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 1: CRD (The Definition)                                    │
│                                                                  │
│ "I define a new kind of resource called LLMModel"                │
│                                                                  │
│ - Defines schema (what fields exist)                             │
│ - Lives in Kubernetes API (you can kubectl get it)               │
│ - Stored in etcd                                                 │
│ - DOES NOT RUN ANYTHING                                          │
└─────────────────────────────────────────────────────────────────┘
                           │
                           │ When you create an instance...
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 2: Custom Resource (The Instance)                          │
│                                                                  │
│ "I want a llama-3-70b model with 3 replicas"                     │
│                                                                  │
│ - An instance of the CRD                                         │
│ - YAML file you write and apply                                  │
│ - Contains your desired state                                    │
│ - STILL DOES NOT RUN ANYTHING                                    │
└─────────────────────────────────────────────────────────────────┘
                           │
                           │ Operator notices and takes action...
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 3: Operator (The Controller)                               │
│                                                                  │
│ "I see LLMModel, I'll create a Deployment with pods"             │
│                                                                  │
│ - Watches custom resources                                       │
│ - Creates/updates actual Kubernetes resources                    │
│ - THIS IS WHERE CONTAINERS GET CREATED                           │
│ - Runs as a Deployment itself                                    │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ RESULT: Actual Running Containers                                │
│                                                                  │
│ - Deployment (created by operator)                               │
│ - Pods (created by deployment)                                   │
│ - Containers in pods (running your model)                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Step-by-Step: From CRD to Running Container

### Step 1: Define the CRD (The API)

**File**: `01-what-is-crd.yaml`

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: llmmodels.ai.example.com
spec:
  group: ai.example.com
  names:
    kind: LLMModel
    plural: llmmodels
  scope: Namespaced
  versions:
  - name: v1
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            properties:
              modelName: {type: string}
              replicas: {type: integer}
              gpuType: {type: string}
```

**What this does**:
- Extends Kubernetes API with a new resource type
- Like defining a class in programming (no objects created yet)
- **Nothing runs yet - just a schema definition**

**Command**:
```bash
kubectl apply -f 01-what-is-crd.yaml
```

**What happened**:
- Kubernetes now knows about `LLMModel` resources
- You can do `kubectl get llmmodels` (will be empty)
- Still no containers running!

---

### Step 2: Create an Instance (Your Desired State)

**File**: `my-model.yaml`

```yaml
apiVersion: ai.example.com/v1
kind: LLMModel
metadata:
  name: llama-3-70b-serving
spec:
  modelName: llama-3-70b
  replicas: 3
  gpuType: H100
  modelPath: /models/llama-3-70b
```

**What this does**:
- Creates an instance of the CRD
- Stores your desired state in etcd
- **Still no containers running!**

**Command**:
```bash
kubectl apply -f my-model.yaml
kubectl get llmmodels
# NAME                   MODEL
# llama-3-70b-serving    llama-3-70b
```

**What happened**:
- Your YAML is now stored in Kubernetes
- You can see it with kubectl
- But nothing is actually running yet!
- This is like a database record - just data

---

### Step 3: Deploy the Operator (The Engine)

**File**: `02-simple-operator.yaml`

The operator is a **Deployment that runs code watching for LLMModel resources**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-operator
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: operator
        image: python:3.11-slim
        # The operator code runs here!
        command: ["/bin/sh", "-c", "python /tmp/operator.py"]
```

**What this does**:
- Deploys a pod that runs the operator code
- The operator watches for LLMModel resources
- When it sees one, it creates a Deployment

**Command**:
```bash
kubectl apply -f 02-simple-operator.yaml
kubectl get pods -l app=llm-operator
# NAME                           READY
# llm-operator-xxxxxxxxxx-xxxxx  1/1
```

**What happened**:
- A pod is now running your operator code
- The operator is watching for LLMModel resources
- It notices your `llama-3-70b-serving` resource
- **Now the real magic happens...**

---

### Step 4: The Operator Creates Actual Resources

Inside the operator code (simplified):

```python
def reconcile_llmmodel(llmmodel):
    # 1. Read the LLMModel spec
    name = llmmodel['metadata']['name']  # "llama-3-70b-serving"
    replicas = llmmodel['spec']['replicas']  # 3

    # 2. Create a Deployment (THIS IS WHERE CONTAINERS HAPPEN!)
    deployment = {
        'apiVersion': 'apps/v1',
        'kind': 'Deployment',
        'metadata': {'name': f'llmmodel-{name}'},
        'spec': {
            'replicas': replicas,  # 3
            'template': {
                'spec': {
                    'containers': [{
                        'name': 'model',
                        'image': 'vllm/vllm-openai:latest',  # <-- CONTAINER IMAGE!
                        'env': [
                            {'name': 'MODEL_NAME', 'value': 'llama-3-70b'}
                        ]
                    }]
                }
            }
        }
    }

    # 3. Create the Deployment in Kubernetes
    apps.create_namespaced_deployment(
        namespace='default',
        body=deployment
    )
```

**What this does**:
- The operator reads your LLMModel spec
- It creates a regular Kubernetes Deployment
- The Deployment creates pods
- The pods run containers
- **This is where actual containers are created!**

---

### Step 5: Containers Are Running

```bash
kubectl get deployments
# NAME                          READY
# llmmodel-llama-3-70b-serving  3/3

kubectl get pods
# NAME                                                READY
# llmmodel-llama-3-70b-serving-xxxxxxxxxx-xxxxx       1/1
# llmmodel-llama-3-70b-serving-xxxxxxxxxx-xxxxy       1/1
# llmmodel-llama-3-70b-serving-xxxxxxxxxx-xxxxz       1/1
```

**What happened**:
- The operator created a Deployment
- The Deployment created 3 pods
- Each pod is running a container with your model
- Your LLM is now serving!

---

## The Reconciliation Loop Explained

The operator runs in a continuous loop:

```
┌─────────────────────────────────────────────────────────────┐
│                    RECONCILIATION LOOP                       │
│                     (runs forever)                           │
└─────────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┴──────────────────┐
        │                                      │
        ▼                                      ▼
┌──────────────┐                      ┌──────────────┐
│  Watch API   │                      │  CRD Changed?│
│  for events  │◄─────── No ──────────┤  (ADDED,     │
└──────────────┘                      │   MODIFIED,  │
        │                             │   DELETED)   │
        │ Yes                         └──────┬───────┘
        ▼                                     │
┌──────────────┐                             │
│  Get CRD     │                             │
│  Spec        │                             │
└──────┬───────┘                             │
       │                                     │
       ▼                                     │
┌──────────────┐                             │
│  Get Actual  │                             │
│  State       │                             │
│  (Deployment │                             │
│   exists?)   │                             │
└──────┬───────┘                             │
       │                                     │
       ▼                                     │
┌──────────────┐                             │
│  Compare:    │                             │
│  Desired vs  │                             │
│  Actual      │                             │
└──────┬───────┘                             │
       │                                     │
       ▼                                     │
┌──────────────┐                             │
│  Different?  │─────── No ──────────────────┘
└──────┬───────┘
       │ Yes
       ▼
┌──────────────┐
│  RECONCILE!  │
│  - Create    │
│    Deployment│
│  - Update    │
│    replicas  │
│  - Update    │
│    status    │
└──────────────┘
       │
       │ (Loop repeats)
       └───────►
```

**In plain English**:

1. **Watch**: The operator watches Kubernetes for changes to LLMModel resources
2. **Detect**: When a change happens (create/update/delete), the operator is notified
3. **Read**: The operator reads the LLMModel spec (what you want)
4. **Check**: The operator checks what actually exists (Deployments, pods)
5. **Compare**: If what exists != what you want, the operator takes action
6. **Act**: Create/update/delete resources to match your desired state
7. **Repeat**: Forever (or until the operator stops)

---

## Practical Examples

### Example 1: Creating a New Model

```bash
# You create an LLMModel
kubectl apply -f - <<EOF
apiVersion: ai.example.com/v1
kind: LLMModel
metadata:
  name: my-new-model
spec:
  modelName: llama-3-8b
  replicas: 2
  gpuType: A100
EOF
```

**What happens behind the scenes**:

1. Kubernetes stores the LLMModel in etcd
2. Operator receives `ADDED` event via watch API
3. Operator's `reconcile_llmmodel()` is called
4. Operator sees no Deployment exists for `my-new-model`
5. Operator creates Deployment with 2 replicas
6. Deployment creates 2 pods
7. Each pod runs a container with the llama-3-8b model

**Timeline**:
```
t=0s    You apply LLMModel
t=1s    Kubernetes stores it
t=2s    Operator receives ADDED event
t=3s    Operator creates Deployment
t=10s   Pods are created and scheduled
t=30s   Containers pull images and start
t=60s   Model is ready to serve requests
```

---

### Example 2: Scaling Up

```bash
# You change replicas from 2 to 5
kubectl patch llmmodel my-new-model --type=json \
  -p='[{"op": "replace", "path": "/spec/replicas", "value":5}]'
```

**What happens behind the scenes**:

1. Kubernetes updates LLMModel in etcd
2. Operator receives `MODIFIED` event via watch API
3. Operator's `reconcile_llmmodel()` is called
4. Operator reads spec: replicas=5
5. Operator reads actual Deployment: replicas=2
6. Operator patches Deployment to replicas=5
7. Deployment creates 3 more pods
8. New pods start containers

**No manual intervention needed!**

---

### Example 3: Deleting a Model

```bash
kubectl delete llmmodel my-new-model
```

**What happens behind the scenes**:

1. Kubernetes deletes LLMModel from etcd
2. Operator receives `DELETED` event via watch API
3. Operator's cleanup code runs
4. Operator deletes the Deployment
5. Deployment deletes all pods
6. All containers are stopped

---

## Common Confusions Clarified

### Confusion 1: "CRDs define containers"

**Wrong**: CRDs define containers.

**Right**: CRDs define a schema/API. Operators read that schema and create containers via Deployments/StatefulSets.

---

### Confusion 2: "Creating a CRD instance runs something"

**Wrong**: Applying `kind: LLMModel` YAML runs containers.

**Right**: It just stores data. Only when an operator is watching will containers be created.

**Analogy**:
- CRD instance = A restaurant order ticket
- Operator = The chef who reads tickets and cooks
- Without the chef, the ticket just sits there!

---

### Confusion 3: "The operator is the CRD"

**Wrong**: The CRD is the operator.

**Right**:
- CRD = API definition (like a class definition)
- Operator = Code that watches resources (like a method implementation)

---

### Confusion 4: "I need to write Go to create an operator"

**Wrong**: Operators must be written in Go.

**Right**: Operators can be written in any language:
- Python (using `kubernetes` Python client)
- Go (using `controller-runtime`)
- Java (using Fabric8)
- Bash (using kubectl in a loop!)
- Any language with a Kubernetes client library

---

### Confusion 5: "CRDs are only for complex things"

**Wrong**: CRDs are only for advanced use cases.

**Right**: CRDs are useful whenever you want:
- A domain-specific API (e.g., `ModelDeployment` instead of `Deployment`)
- Abstraction over complex resources
- Automation of repetitive tasks
- Validation of user inputs

**Simple example**:
```yaml
# Instead of:
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-model
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        args: ["--model", "llama-3-70b", "--tensor-parallel-size", "4"]
        resources:
          limits:
            nvidia.com/gpu: 4

# You can write:
apiVersion: ai.example.com/v1
kind: LLMModel
metadata:
  name: my-model
spec:
  modelName: llama-3-70b
  replicas: 3
  gpuCount: 4
```

The CRD version is simpler and hides complexity!

---

## Key Takeaways

1. **CRD = API Definition**: Defines what fields exist, validation rules, names
2. **Custom Resource = Instance**: Your YAML file with desired state
3. **Operator = Controller**: Code that watches resources and takes action
4. **Containers = Result**: Created by operator via Deployments/StatefulSets

```
You write YAML (CRD instance)
         │
         ▼
  Operator notices
         │
         ▼
Operator creates Deployment
         │
         ▼
Deployment creates Pods
         │
         ▼
Pods run Containers
```

---

## Related Files in This Directory

| File | Purpose |
|------|---------|
| `01-what-is-crd.yaml` | CRD definition (Layer 1) |
| `02-simple-operator.yaml` | Operator deployment + code (Layer 3) |
| `01-test-crd.sh` | Test script for CRD only |
| `02-test-operator.sh` | Test script for full operator |
| `README.md` | Overview and examples |

---

## Next Steps

1. **Try it yourself**: Run `./01-test-crd.sh` to see CRD without operator
2. **Add the operator**: Run `./02-test-operator.sh` to see full flow
3. **Watch logs**: `kubectl logs -l app=llm-operator -f` to see reconciliation
4. **Experiment**: Create your own LLMModel and watch what happens

---

## Further Reading

- [Kubernetes CRD Documentation](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [Kubebuilder Book](https://book.kubebuilder.io/)
- [Operator Pattern Guide](https://kubernetes.io/docs/concepts/architecture/controller/)
