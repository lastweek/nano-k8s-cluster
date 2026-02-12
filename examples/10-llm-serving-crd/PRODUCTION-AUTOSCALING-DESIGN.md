# Production Autoscaling Design

## Objective

Scale serving capacity without breaking tensor-parallel correctness.

## Non-negotiable invariant

Each `LLMCluster` is a fixed-shape serving unit.

- Scale out/in by creating or deleting whole `LLMCluster` objects.
- Do not mutate TP backend shape for capacity scaling.

## Monolithic fleet autoscaling (implemented path)

Policy file: `06-example-with-crd-autoscaler.yaml`

Controller input fields consumed by `operator-autoscaler.go`:

- `spec.scaleTargetRef`
- `spec.minInstances` / `spec.maxInstances`
- `spec.metrics[].query` and thresholds
- `spec.instanceTemplate`
- `spec.routerRef`
- `spec.behavior.scaleUpStabilizationSeconds`
- `spec.behavior.scaleDownStabilizationSeconds`

Decision model:

- Scale up when any metric breaches `scaleUp` threshold and cooldown allows.
- Scale down when all metrics are below `scaleDown` thresholds and cooldown allows.
- One step per reconcile to avoid oscillation.

## PD-disaggregated autoscaling (target API path)

Policy shape: `10-disaggregated-autoscaler.yaml`

The CRD supports separate prefill and decode policies. This is the intended end-state for independent phase scaling. Current controller implementation is still centered on the monolithic fields listed above.

## Safety defaults

- Stabilization windows for both scale directions.
- Label-selected fleet ownership.
- Router backend reconciliation during instance churn.
- Status updates on autoscaler CR for observability.

## Build and deploy autoscaler image

```bash
docker build -f Dockerfile.autoscaler -t ghcr.io/<org>/llmcluster-autoscaler:v0.1.0 .
docker push ghcr.io/<org>/llmcluster-autoscaler:v0.1.0
kubectl apply -f 07-operator-deployment.yaml
```
