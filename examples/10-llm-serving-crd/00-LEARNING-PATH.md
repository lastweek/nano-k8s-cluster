# Learning Path: Monolithic to PD-Disaggregated

Use this sequence to understand and deploy incrementally.

## Phase 0: Foundation

Apply core APIs and controllers:

```bash
kubectl apply -f 00-llmcluster-crd.yaml
kubectl apply -f 00-llmclusterautoscaler-crd.yaml
kubectl apply -f 01-rbac.yaml
kubectl apply -f 02-operator-deployment.yaml
kubectl apply -f 07-operator-deployment.yaml
```

Verify:

```bash
kubectl get crd | grep serving.ai
kubectl get deploy -n default | grep llmcluster
```

## Phase 1: Single monolithic instance

Deploy one TP-fixed instance:

```bash
kubectl apply -f 03-example-simple-llmcluster.yaml
kubectl get llmc -w
```

## Phase 2: Multi-instance monolithic + router

Deploy two serving instances plus shared router:

```bash
kubectl apply -f 04-example-with-router.yaml
```

## Phase 3: Monolithic fleet autoscaling

Enable autoscaler policy for instance fleet:

```bash
kubectl apply -f 06-example-with-crd-autoscaler.yaml
kubectl get llmca -w
```

## Phase 4: PD-disaggregated serving

Split prefill and decode clusters:

```bash
kubectl apply -f 08-disaggregated-prefill-decode.yaml
```

## Phase 5: PD-disaggregated autoscaling policy

Apply disaggregated policy schema:

```bash
kubectl apply -f 10-disaggregated-autoscaler.yaml
```

Current implementation note: `operator-autoscaler.go` primarily reconciles monolithic fields (`scaleTargetRef`, `metrics`, `instanceTemplate`). The disaggregated policy file documents the target API and planned control behavior.
