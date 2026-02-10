# Kubernetes Services Examples

This section covers Kubernetes Services - the abstraction that provides network connectivity to pods.

## Prerequisites

- Kubernetes cluster running (minikube, kind, or k3s)
- kubectl configured and working
- Basic understanding of Pods and Deployments

## Learning Objectives

After completing these examples, you will understand:

1. **Service types**: ClusterIP, NodePort, LoadBalancer
2. **Service discovery**: DNS-based service discovery
3. **Load balancing**: How services distribute traffic across pods
4. **Stable endpoints**: How services provide stable network identities

## Examples

### 01: ClusterIP Service (Internal Access)

**File**: [01-clusterip.yaml](01-clusterip.yaml)

Learn:
- Default service type for internal cluster access
- Service DNS names
- Load balancing across pods
- Stable service IP vs ephemeral pod IPs

**Run**:
```bash
./01-test-clusterip.sh
```

**Key concepts**:
- Service gets cluster-internal IP
- DNS: `<service-name>.<namespace>.svc.cluster.local`
- Load balances traffic across all matching pods
- Only accessible from within the cluster

**For LLM serving**:
- Use for internal service-to-service communication
- Example: Frontend API → Serving Layer → Model Inference Pods

---

### 02: NodePort Service (External Access)

**File**: [02-nodeport.yaml](02-nodeport.yaml)

Learn:
- External access via `<NodeIP>:<NodePort>`
- Port mapping: NodePort → Service Port → Container Port
- NodePort also creates ClusterIP for internal access
- Works on all nodes (not just where pods run)

**Run**:
```bash
./02-test-nodeport.sh
```

**Key concepts**:
- Exposes service on each node's IP at a static port (30000-32767)
- Allows external access during development
- Also has ClusterIP for internal access
- Production: Use LoadBalancer or Ingress instead

**For LLM serving**:
- Useful for development and testing
- Test model serving from local machine
- Production: Use LoadBalancer or Ingress

---

### 03: Service Discovery and DNS

**File**: [03-service-discovery.yaml](03-service-discovery.yaml)

Learn:
- DNS records: `<service>.<namespace>.svc.cluster.local`
- Short names within namespace
- Cross-namespace service discovery
- DNS automatically updates as pods scale

**Run**:
```bash
./03-test-service-discovery.sh
```

**Key concepts**:
- Built-in DNS server (CoreDNS)
- Services automatically registered
- DNS updates dynamically as pods are added/removed
- Cross-namespace communication: `<service>.<namespace>`

**For LLM serving**:
- Services discover each other via DNS
- No hardcoded IPs
- Enables dynamic scaling without breaking connections

---

## Running All Examples

Run all service examples sequentially:

```bash
./test-all-services.sh
```

This will:
1. Run each example in order
2. Clean up resources between examples
3. Show progress and results

## Cleanup

Clean up all service examples:

```bash
./cleanup-all-services.sh
```

Or clean up individual examples:

```bash
kubectl delete -f 01-clusterip.yaml
kubectl delete -f 02-nodeport.yaml
kubectl delete -f 03-service-discovery.yaml
```

## Service Types Comparison

| Type | Scope | Use Case | For LLM Serving |
|------|-------|----------|-----------------|
| ClusterIP | Cluster internal | Service-to-service communication | Internal API communication |
| NodePort | Node IP:Port | Development, testing | Testing model serving locally |
| LoadBalancer | Cloud load balancer | Production external access | Production model serving |
| Headless | Direct pod IPs | Stateful apps, need direct access | Distributed training coordination |

## Common Commands

```bash
# List services
kubectl get services

# Describe a service
kubectl describe service <service-name>

# Get service IP
kubectl get service <service-name> -o jsonpath='{.spec.clusterIP}'

# Get service endpoints (pod IPs)
kubectl get endpoints <service-name>

# Test service from within cluster
kubectl run test --rm -it --image=curlimages/curl -- curl http://<service-name>

# For NodePort, get the node port
kubectl get service <service-name> -o jsonpath='{.spec.ports[0].nodePort}'
```

## Architecture: Services in LLM Serving

```
                    ┌─────────────────┐
                    │   Ingress / LB  │
                    │   (External)    │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Frontend API   │
                    │  (ClusterIP)    │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
    ┌─────────▼──────┐ ┌────▼─────┐ ┌────▼─────┐
    │ Model Serving  │ │  Model   │ │  Model   │
    │    (ClusterIP) │ │ Serving  │ │ Serving  │
    └─────────┬──────┘ └────┬─────┘ └────┬─────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
              ┌──────────────▼──────────────┐
              │     Model Pods (GPU)        │
              │  Stable identity via StatefulSet │
              └─────────────────────────────┘
```

## Next Steps

After mastering Services:
1. **ConfigMaps and Secrets** - Configuration and sensitive data
2. **Storage** - Persistent volumes for model checkpoints
3. **StatefulSets** - For stateful applications like databases
4. **Ingress** - HTTP/HTTPS routing for external access

## References

- [Kubernetes Services Documentation](https://kubernetes.io/docs/concepts/services-networking/service/)
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Service Discovery](https://kubernetes.io/docs/concepts/services-networking/service-discovery/)
