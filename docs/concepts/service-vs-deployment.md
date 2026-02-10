# Service vs Deployment

## The Core Difference

| Aspect | Deployment | Service |
|--------|-----------|---------|
| **Purpose** | Manages application pods | Provides network access to pods |
| **What it does** | Creates, scales, updates pods | Gives pods a stable DNS name/IP |
| **Network** | No network identity | Stable IP/DNS name |
| **Load balancing** | None | Distributes traffic across pods |
| **Analogy** | Factory that produces widgets | Storefront that sells widgets |

## Deployment - The Application Manager

A **Deployment** manages your application's pods.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3                    # Run 3 pods
  selector:
    matchLabels:
      app: nginx
  template:                      # Pod template
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
```

**What Deployment does:**
- Creates 3 nginx pods (named `nginx-deployment-xxx`, `nginx-deployment-yyy`, `nginx-deployment-zzz`)
- If a pod dies, Deployment creates a new one (self-healing)
- If you update the image, Deployment gradually replaces pods (rolling update)
- If you scale to 5 replicas, Deployment adds 2 more pods

**Problem:** Pods have random names and changing IPs. Other services can't reliably find them.

## Service - The Network Abstraction

A **Service** provides stable network access to a set of pods.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx                   # Find pods with this label
  ports:
  - port: 80                    # Service port
    targetPort: 80              # Pod port
```

**What Service does:**
- Gets a stable IP: `10.96.0.100`
- Gets a DNS name: `nginx-service.default.svc.cluster.local`
- Load balances traffic across all matching pods
- Automatically updates as pods are added/removed

## How They Work Together

```
Deployment (nginx-deployment)          Service (nginx-service)
┌─────────────────────────────┐        ┌──────────────────────────┐
│                             │        │                          │
│  ┌──────┐  ┌──────┐         │        │   Stable IP: 10.96.0.100│
│  │Pod-1 │  │Pod-2 │  ┌─────┐ │  ────▶│   DNS: nginx-service   │
│  │:IP1  │  │:IP2  │  │Pod-3│ │        │                          │
│  └──────┘  └──────┘  └:IP3 ┘ │        │   Load Balancer:        │
│                             │        │   Pod-1 ←→ 33% traffic   │
│  - Self-healing             │        │   Pod-2 ←→ 33% traffic   │
│  - Scaling                  │        │   Pod-3 ←→ 33% traffic   │
│  - Rolling updates          │        │                          │
└─────────────────────────────┘        └──────────────────────────┘
```

**Flow:**
1. **Deployment** creates 3 pods with label `app: nginx`
2. **Service** finds those pods using selector `app: nginx`
3. **Service** gets stable IP and DNS name
4. Traffic to `nginx-service` is distributed across all 3 pods

## Complete Example

```yaml
---
# Deployment: Manages the pods
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web               # Label that Service will find
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80

---
# Service: Provides network access
apiVersion: v1
kind: Service
metadata:
  name: web-service          # Stable DNS name
spec:
  selector:
    app: web                 # Find pods with this label
  ports:
  - port: 80                # Clients connect to this port
    targetPort: 80           # Traffic sent to pod port 80
```

**Result:**
- Deployment creates 3 pods with random IPs
- Service gets stable IP: `10.96.0.50`
- Clients access: `http://web-service` or `http://10.96.0.50`
- Service load balances across all 3 pods
- If pod dies, Deployment replaces it, Service updates automatically

## Key Differences

### 1. Purpose
```
Deployment                    Service
     │                          │
     ▼                          ▼
┌─────────────┐          ┌─────────────┐
│ "Run these   │          │ "Give these │
│  3 nginx pods"│          │  pods an IP"│
└─────────────┘          └─────────────┘
```

### 2. Network Identity
```
Deployment creates:          Service creates:
- Pod names (random)         - Stable IP
- Pod IPs (ephemeral)        - Stable DNS name
                              - Load balancing
```

### 3. What Happens When Pod Dies
```
Deployment:
  Pod dies → Deployment notices → Creates new pod
                                    (new name, new IP)

Service:
  Pod dies → Service updates endpoint list
                                    (remove dead pod IP)
```

### 4. Scaling
```
Deployment:
  Scale 3→5 → Creates 2 new pods

Service:
  Automatically includes new pods in load balancing
  (no configuration change needed!)
```

## Do You Need Both?

| Scenario | Deployment? | Service? |
|----------|-------------|----------|
| Run a web application | ✅ Yes | ✅ Yes |
| Run a one-time batch job | ✅ Yes (maybe Job) | ❌ No |
| Expose an app externally | ✅ Yes | ✅ Yes (or Ingress) |
| Background worker | ✅ Yes | ❌ No* |

*Workers might need Service if other pods need to discover them.

## Real-World Example: LLM Serving

```
┌─────────────────────────────────────────────────────────────┐
│                    LLM Serving Cluster                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Deployment: model-serving                                  │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                     │
│  │ Pod-1   │  │ Pod-2   │  │ Pod-3   │                      │
│  │ LLM v1  │  │ LLM v1  │  │ LLM v1  │  ← Deployment manages│
│  │ :10.1.1 │  │ :10.1.2 │  │ :10.1.3 │                     │
│  └─────────┘  └─────────┘  └─────────┘                     │
│       │            │            │                           │
│       └────────────┴────────────┘                           │
│                     │                                       │
│                     ▼                                       │
│            Service: model-serving                           │
│         IP: 10.96.0.100                                     │
│         DNS: model-serving.default.svc.cluster.local       │
│                                                             │
│  Clients connect to: model-serving (stable endpoint)       │
│  Service load balances across all pods                     │
└─────────────────────────────────────────────────────────────┘
```

## Commands Comparison

```bash
# Deployment commands
kubectl create deployment nginx --image=nginx
kubectl scale deployment nginx --replicas=5
kubectl set image deployment/nginx nginx=nginx:1.26
kubectl rollout status deployment/nginx
kubectl rollout undo deployment/nginx

# Service commands
kubectl expose deployment nginx --port=80
kubectl get services
kubectl describe service nginx
```

## Summary

| Question | Answer |
|----------|--------|
| **What does Deployment do?** | Manages pods (creates, scales, updates) |
| **What does Service do?** | Provides stable network access |
| **Can I have Deployment without Service?** | Yes, but pods have no stable address |
| **Can I have Service without Deployment?** | Yes, can point to any pods matching labels |
| **Do I need both?** | Usually yes for web applications |

## Mental Model

Think of a **pizza restaurant**:

- **Deployment** = Kitchen + chefs
  - Makes pizzas (runs pods)
  - Scales up/down (adds/removes chefs)
  - Replaces tired chefs (restarts pods)

- **Service** = Restaurant front + phone number
  - Stable address (phone number doesn't change)
  - Takes orders (receives traffic)
  - Routes to kitchen (load balances to chefs)

Customers call the restaurant's phone number (Service), they don't call individual chefs directly (pods with changing IPs).
