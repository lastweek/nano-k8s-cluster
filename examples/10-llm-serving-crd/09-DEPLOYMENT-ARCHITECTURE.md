# System Architecture

This example models two planes:

- Control plane: CRDs plus reconcilers that materialize runtime objects.
- Data plane: LLM serving instances, router, queue, and metrics backends.

## Control plane components

- `LLMCluster` CRD: `00-llmcluster-crd.yaml`
- `LLMClusterAutoscaler` CRD: `00-llmclusterautoscaler-crd.yaml`
- Serving operator RBAC/deployment:
  - `01-rbac.yaml`
  - `02-operator-deployment.yaml`
- Fleet autoscaler operator deployment:
  - `07-operator-deployment.yaml`
- Serving reconciler source: `controller/main.go`
- Fleet autoscaler source: `operator-autoscaler.go`

## Data plane variants

### Monolithic serving

- Single instance baseline: `03-example-simple-llmcluster.yaml`
- Multi-instance with router: `04-example-with-router.yaml`
- Router HPA example: `05-example-with-autoscaling.yaml`
- Monolithic fleet policy: `06-example-with-crd-autoscaler.yaml`

### Prefill/decode disaggregated serving

- PD clusters and router wiring: `08-disaggregated-prefill-decode.yaml`
- PD autoscaler policy shape: `10-disaggregated-autoscaler.yaml`

## Deployment order

```bash
kubectl apply -f 00-llmcluster-crd.yaml
kubectl apply -f 00-llmclusterautoscaler-crd.yaml
kubectl apply -f 01-rbac.yaml
kubectl apply -f 02-operator-deployment.yaml
kubectl apply -f 07-operator-deployment.yaml

kubectl apply -f 03-example-simple-llmcluster.yaml
kubectl apply -f 04-example-with-router.yaml
kubectl apply -f 06-example-with-crd-autoscaler.yaml

kubectl apply -f 08-disaggregated-prefill-decode.yaml
kubectl apply -f 10-disaggregated-autoscaler.yaml
```

## Operational checks

```bash
kubectl get llmc
kubectl get llmca
kubectl get deploy -l app=llmcluster-operator
kubectl get deploy -l app=llmcluster-autoscaler
```
