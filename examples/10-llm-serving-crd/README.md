# LLM Serving CRD Example

This example is organized as a progressive path from a single LLM serving instance to a prefill/decode (PD) disaggregated topology.

## Why this layout

The previous layout mixed CRDs, operators, examples, and deep docs in one numbered list. This version separates concerns so the learning path is explicit:

1. Install platform foundations.
2. Deploy monolithic serving.
3. Add fleet autoscaling.
4. Move to PD-disaggregated serving.

## File layout (flat)

```text
10-llm-serving-crd/
├── 00-llmcluster-crd.yaml
├── 00-llmclusterautoscaler-crd.yaml
├── 00-LEARNING-PATH.md
├── 01-rbac.yaml
├── 02-operator-deployment.yaml
├── 03-example-simple-llmcluster.yaml
├── 04-example-with-router.yaml
├── 05-example-with-autoscaling.yaml
├── 06-example-with-crd-autoscaler.yaml
├── 07-operator-deployment.yaml
├── 08-disaggregated-prefill-decode.yaml
├── 09-DEPLOYMENT-ARCHITECTURE.md
├── 10-disaggregated-autoscaler.yaml
├── 11-ARCHITECTURE-DIAGRAMS.md
├── PRODUCTION-AUTOSCALING-DESIGN.md
├── controller/
├── operator-autoscaler.go
└── Dockerfile.autoscaler
```

## Fast start (staged)

```bash
# 0) Foundation
kubectl apply -f 00-llmcluster-crd.yaml
kubectl apply -f 00-llmclusterautoscaler-crd.yaml
kubectl apply -f 01-rbac.yaml
kubectl apply -f 02-operator-deployment.yaml
kubectl apply -f 07-operator-deployment.yaml

# 1) Monolithic baseline
kubectl apply -f 03-example-simple-llmcluster.yaml

# 2) Monolithic with shared router
kubectl apply -f 04-example-with-router.yaml

# 3) Fleet autoscaling (monolithic instances)
kubectl apply -f 06-example-with-crd-autoscaler.yaml

# 4) PD-disaggregated serving
kubectl apply -f 08-disaggregated-prefill-decode.yaml

# 5) PD-disaggregated autoscaling policy (design path)
kubectl apply -f 10-disaggregated-autoscaler.yaml
```

## Key architecture rule

Treat each `LLMCluster` as a fixed-shape TP instance. Scale capacity by adding/removing whole `LLMCluster` objects, not by mutating TP backend pod counts.

## Docs

- Learning path: `00-LEARNING-PATH.md`
- System architecture: `09-DEPLOYMENT-ARCHITECTURE.md`
- Production autoscaling design: `PRODUCTION-AUTOSCALING-DESIGN.md`
- Mermaid diagrams: `11-ARCHITECTURE-DIAGRAMS.md`
