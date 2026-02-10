# Deployment vs StatefulSet for LLM Cluster

---
## Scenario: 3-Pod Training Job

### Using Deployment (WRONG for training!)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: training-wrong
spec:
  replicas: 3
  selector:
    matchLabels:
      app: training
  template:
    metadata:
      labels:
        app: training
    spec:
      containers:
      - name: trainer
        image: pytorch:2.1
        command: ["python", "train.py"]
        env:
        - name: RANK
          value: "0"  # Problem: All pods use same rank!

# Problem:
# - All pods are called "training-worker-abc123", "training-worker-def456", etc.
# - Each pod thinks it's rank 0!
# - If pod crashes and gets new name, checkpoint is lost!
# - No stable network identity for distributed training

---
## Using StatefulSet (CORRECT for training!)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: training-correct
spec:
  serviceName: "training"  # Headless service
  replicas: 3
  selector:
    matchLabels:
      app: training
  template:
    metadata:
      labels:
        app: training
    spec:
      containers:
      - name: trainer
        image: pytorch:2.1
        command: ["python", "train.py"]
        env:
        - name: RANK
          valueFrom:
            fieldRef:
              fieldPath: metadata.name  # Extracts rank from pod name!
        volumeMounts:
        - name: checkpoint
          mountPath: /checkpoints
  volumeClaimTemplates:
  - metadata:
      name: checkpoint
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 10Gi

# Benefits:
# - Pods are named training-correct-0, training-correct-1, training-correct-2
# - Each pod knows its rank from its name!
# - Each pod gets its own PVC for checkpoints
# - Stable network: training-correct-0.training-correct.training-0
