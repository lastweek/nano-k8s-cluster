#!/bin/bash
# Test script for 02-distributed-training.yaml
#
# This script demonstrates StatefulSet for distributed training.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
WARN='\033[0;35m'      # Magenta for warnings
NC='\033[0m'           # No Color

set -e

# Show script filename
echo -e "${INFO}===================================${NC}"
echo -e "${INFO}Script: 02-test-distributed-training.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: StatefulSet for Distributed Training"
echo "==================================="
echo ""

# Apply the StatefulSet
echo -e "${INFO}Step 1: Creating StatefulSet for distributed training...${NC}"
echo -e "${CMD}$ kubectl apply -f 02-distributed-training.yaml${NC}"
kubectl apply -f 02-distributed-training.yaml
echo ""

# Show StatefulSet
echo -e "${INFO}Step 2: Show StatefulSet...${NC}"
echo -e "${CMD}$ kubectl get statefulset trainer${NC}"
kubectl get statefulset trainer
echo ""

# Wait for pods to be ready (ordered deployment)
echo -e "${INFO}Step 3: Waiting for trainer pods (ordered: 0 → 1 → 2)...${NC}"
kubectl wait --for=condition=ready pod -l app=distributed-training --timeout=180s > /dev/null
echo -e "${SUCCESS}   ✓ All trainer pods ready${NC}"
echo ""

# Show pods with their ranks
echo -e "${INFO}Step 4: Show trainer pods with ranks...${NC}"
echo -e "${CMD}$ kubectl get pods -l app=distributed-training${NC}"
kubectl get pods -l app=distributed-training
echo ""

# Show pod details with ranks
echo -e "${INFO}Step 5: Show pod ranks (extracted from pod names)...${NC}"
echo ""
for i in 0 1 2; do
    POD_NAME=$(kubectl get pods -l app=distributed-training -o jsonpath="{.items[$i].metadata.name}")
    POD_IP=$(kubectl get pod $POD_NAME -o jsonpath='{.status.podIP}')
    echo "  $POD_NAME"
    echo "    Rank: $i (from pod name)"
    echo "    IP: $POD_IP"
    echo "    DNS: $POD_NAME.training.default.svc.cluster.local"
    echo ""
done

# Show PVCs
echo -e "${INFO}Step 6: Show PVCs (checkpoint storage for each pod)...${NC}"
echo -e "${CMD}$ kubectl get pvc -l app=distributed-training${NC}"
kubectl get pvc -l app=distributed-training
echo ""

# Show training logs from each pod
echo -e "${INFO}Step 7: Show training logs from each pod...${NC}"
echo ""
for i in 0 1 2; do
    echo "  ├── Trainer-$i logs:"
    echo -e "${CMD}$ kubectl logs trainer-$i${NC}"
    kubectl logs trainer-$i | grep -E "Pod:|Rank:|Master:|Step|checkpoint" | head -15
    echo ""
done

# Show checkpoints
echo -e "${INFO}Step 8: Show checkpoints on each pod...${NC}"
echo ""
for i in 0 1 2; do
    echo "  ├── Trainer-$i checkpoints:"
    echo -e "${CMD}$ kubectl exec trainer-$i -- ls -lh /checkpoints${NC}"
    kubectl exec trainer-$i -- ls -lh /checkpoints 2>/dev/null || echo "    (No checkpoints yet)"
    echo ""
done

# Show DNS resolution
echo -e "${INFO}Step 9: Verify DNS-based pod discovery...${NC}"
echo ""
echo "  Pods can discover each other via DNS:"
echo ""
for i in 0 1 2; do
    echo "  Resolving trainer-$i:"
    kubectl run dns-test-$i --rm -it --image=nicolaka/netshoot --restart=Never -- nslookup trainer-$i.training > /tmp/dns$i.txt 2>&1 || true
    DNS_IP=$(kubectl get pod trainer-$i -o jsonpath='{.status.podIP}')
    echo "    DNS: trainer-$i.training → $DNS_IP"
    echo ""
done

# Demonstrate rank extraction
echo -e "${INFO}Step 10: Demonstrate rank extraction...${NC}"
echo ""
echo "  Each pod extracts its rank from the pod name:"
echo ""
for i in 0 1 2; do
    RANK_ENV=$(kubectl exec trainer-$i -- env | grep RANK | cut -d= -f2)
    POD_NAME=$(kubectl exec trainer-$i -- env | grep POD_NAME | cut -d= -f2)
    echo "  trainer-$i:"
    echo "    POD_NAME: $POD_NAME"
    echo "    RANK: $RANK_ENV (extracted from pod name)"
    echo ""
done

# Show distributed training architecture
echo -e "${INFO}Step 11: Distributed training architecture...${NC}"
echo ""
echo "  ┌─────────────────────────────────────────────────────────┐"
echo "  │                  Distributed Training                   │"
echo "  ├─────────────────────────────────────────────────────────┤"
echo "  │                                                           │"
echo "  │  trainer-0 (Rank 0 - Master)                             │"
echo "  │  ├── DNS: trainer-0.training                             │"
echo "  │  ├── PVC: checkpoints-trainer-0                          │"
echo "  │  └── Role: Coordinates training, aggregates gradients   │"
echo "  │                                                           │"
echo "  │  trainer-1 (Rank 1 - Worker)                             │"
echo "  │  ├── DNS: trainer-1.training                             │"
echo "  │  ├── PVC: checkpoints-trainer-1                          │"
echo "  │  └── Role: Processes data shard 1                       │"
echo "  │                                                           │"
echo "  │  trainer-2 (Rank 2 - Worker)                             │"
echo "  │  ├── DNS: trainer-2.training                             │"
echo "  │  ├── PVC: checkpoints-trainer-2                          │"
echo "  │  └── Role: Processes data shard 2                       │"
echo "  │                                                           │"
echo "  └─────────────────────────────────────────────────────────┘"
echo ""

# Demonstrate checkpoint persistence
echo -e "${INFO}Step 12: Demonstrate checkpoint persistence...${NC}"
echo ""
echo "  Deleting trainer-1 to demonstrate checkpoint persistence..."
echo ""
TRAINER_1_CHECKPOINTS_BEFORE=$(kubectl exec trainer-1 -- ls /checkpoints 2>/dev/null | wc -l | tr -d ' ')
echo "  Checkpoints before deletion: $TRAINER_1_CHECKPOINTS_BEFORE"
echo ""
echo -e "${CMD}$ kubectl delete pod trainer-1${NC}"
kubectl delete pod trainer-1 --ignore-not-found=true > /dev/null

sleep 5

echo "  Waiting for trainer-1 to be recreated..."
kubectl wait --for=condition=ready pod/trainer-1 --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ trainer-1 recreated${NC}"
echo ""

TRAINER_1_CHECKPOINTS_AFTER=$(kubectl exec trainer-1 -- ls /checkpoints 2>/dev/null | wc -l | tr -d ' ')
echo "  Checkpoints after recreation: $TRAINER_1_CHECKPOINTS_AFTER"
echo ""

if [ "$TRAINER_1_CHECKPOINTS_BEFORE" -eq "$TRAINER_1_CHECKPOINTS_AFTER" ] && [ "$TRAINER_1_CHECKPOINTS_AFTER" -gt 0 ]; then
    echo -e "${SUCCESS}   ✓ Checkpoints persisted!${NC}"
    echo ""
    echo "  Checkpoint files:"
    kubectl exec trainer-1 -- ls -lh /checkpoints
else
    echo -e "${WARN}   Checkpoint count changed or no checkpoints${NC}"
fi
echo ""

# Show framework integration examples
echo -e "${INFO}Step 13: Framework integration examples...${NC}"
echo ""
echo "  PyTorch DDP:"
echo "    export MASTER_ADDR=trainer-0.training"
echo "    export MASTER_PORT=29500"
echo "    export WORLD_SIZE=3"
echo "    export RANK=\$(hostname | rev | cut -d- -f1 | rev)"
echo "    python -m torch.distributed.launch --nproc_per_node=1 train.py"
echo ""
echo "  DeepSpeed:"
echo "    ds_launch \\"
echo "      --master_addr=trainer-0.training \\"
echo "      --world_size=3 \\"
echo "      train.py"
echo ""
echo "  Megatron-LM:"
echo "    Uses distributed launcher with rank allocation"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ StatefulSet provides stable identity for distributed training"
echo "  ✓ Ranks extracted from pod names (trainer-0 → rank 0)"
echo "  ✓ Headless service enables DNS-based pod discovery"
echo "  ✓ Per-pod PVCs for checkpoint storage"
echo "  ✓ Checkpoints persist across pod restarts"
echo ""
echo "Why this matters for LLM training:"
echo "  - PyTorch DDP / DeepSpeed require stable ranks"
echo "  - Rank 0 is always the master/coordinator"
echo "  - Workers can reach master at stable DNS name"
echo "  - Each worker has its own checkpoint directory"
echo "  - Resume training from checkpoints on pod restart"
echo ""
echo "StatefulSet and pods are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 02-distributed-training.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-stateful-apps.sh"
echo ""
