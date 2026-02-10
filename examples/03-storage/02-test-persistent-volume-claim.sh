#!/bin/bash
# Test script for 02-persistent-volume-claim.yaml
#
# This script demonstrates PVC usage.

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
echo -e "${INFO}Script: 02-test-persistent-volume-claim.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: PersistentVolumeClaim (PVC)"
echo "==================================="
echo ""

# Apply the PVC and deployment
echo -e "${INFO}Step 1: Creating PVC and deployment...${NC}"
echo -e "${CMD}$ kubectl apply -f 02-persistent-volume-claim.yaml${NC}"
kubectl apply -f 02-persistent-volume-claim.yaml
echo ""

# Wait for PVC to be bound
echo -e "${INFO}Step 2: Waiting for PVC to be bound...${NC}"
kubectl wait --for=condition=bound pvc/model-storage --timeout=60s > /dev/null 2>&1 || {
    echo -e "${WARN}   PVC not immediately bound (this is normal)${NC}"
}
kubectl get pvc model-storage
echo ""

# Show PVC status
echo -e "${INFO}Step 3: Show PVC status...${NC}"
echo -e "${CMD}$ kubectl describe pvc model-storage${NC}"
kubectl describe pvc model-storage
echo ""

# Wait for deployment to be ready
echo -e "${INFO}Step 4: Waiting for deployment to be ready...${NC}"
kubectl rollout status deployment/model-server --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ Deployment ready${NC}"
echo ""

# Show pod
echo -e "${INFO}Step 5: Show pod...${NC}"
echo -e "${CMD}$ kubectl get pods -l app=model-server${NC}"
kubectl get pods -l app=model-server
echo ""

# Get pod name
POD_NAME=$(kubectl get pods -l app=model-server -o jsonpath='{.items[0].metadata.name}')

# Show volume mounts
echo -e "${INFO}Step 6: Show volume mounts in pod...${NC}"
echo -e "${CMD}$ kubectl exec $POD_NAME -- df -h /models${NC}"
kubectl exec $POD_NAME -- df -h /models
echo ""

# Show files in /models
echo -e "${INFO}Step 7: Show files in /models...${NC}"
echo -e "${CMD}$ kubectl exec $POD_NAME -- ls -lah /models${NC}"
kubectl exec $POD_NAME -- ls -lah /models
echo ""

# Write some data to persistent storage
echo -e "${INFO}Step 8: Write data to persistent storage...${NC}"
kubectl exec $POD_NAME -- sh -c "echo 'This is persistent data' > /models/test.txt"
kubectl exec $POD_NAME -- sh -c "echo 'Model checkpoint 1' > /models/checkpoint1.bin"
kubectl exec $POD_NAME -- sh -c "echo 'Model checkpoint 2' > /models/checkpoint2.bin"
echo ""
echo "  Files created:"
echo -e "${CMD}$ kubectl exec $POD_NAME -- ls -lh /models${NC}"
kubectl exec $POD_NAME -- ls -lh /models
echo ""

# Show PV that was created
echo -e "${INFO}Step 9: Show PersistentVolume...${NC}"
kubectl get pv
echo ""

# Demonstrate persistence across pod restart
echo -e "${INFO}Step 10: Demonstrate persistence across pod restart...${NC}"
echo ""
echo "  Deleting pod to test data persistence..."
POD_NAME_OLD=$POD_NAME
echo -e "${CMD}$ kubectl delete pod $POD_NAME_OLD${NC}"
kubectl delete pod $POD_NAME_OLD --ignore-not-found=true > /dev/null

sleep 5

echo "  Waiting for new pod..."
kubectl wait --for=condition=ready pod -l app=model-server --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ New pod ready${NC}"
echo ""

POD_NAME_NEW=$(kubectl get pods -l app=model-server -o jsonpath='{.items[0].metadata.name}')
echo "  New pod name: $POD_NAME_NEW"
echo ""
echo "  Checking if data persists..."
echo -e "${CMD}$ kubectl exec $POD_NAME_NEW -- cat /models/test.txt${NC}"
kubectl exec $POD_NAME_NEW -- cat /models/test.txt
echo ""
echo "  All files:"
echo -e "${CMD}$ kubectl exec $POD_NAME_NEW -- ls -lh /models${NC}"
kubectl exec $POD_NAME_NEW -- ls -lh /models
echo ""
echo -e "${SUCCESS}   ✓ Data persisted across pod restart!${NC}"
echo ""

# Show storage classes
echo -e "${INFO}Step 11: Show available storage classes...${NC}"
kubectl get storageclass
echo ""

# Show PVC usage
echo -e "${INFO}Step 12: PVC capacity and usage...${NC}"
echo -e "${CMD}$ kubectl get pvc model-storage${NC}"
kubectl get pvc model-storage
echo ""
echo "  Capacity: 1Gi"
echo "  Note: Usage shown in pod df output"
echo ""

# Explain access modes
echo -e "${INFO}Step 13: Storage access modes...${NC}"
echo ""
echo "  Access Modes:"
echo "    - ReadWriteOnce (RWO): Single node read-write"
echo "      - Used by: Block storage (AWS EBS, GCE PD, Azure Disk)"
echo "      - Allows: Only one pod per node"
echo ""
echo "    - ReadOnlyMany (ROX): Many nodes read-only"
echo "      - Used by: Read-only shared storage"
echo "      - Allows: Multiple pods across nodes (read-only)"
echo ""
echo "    - ReadWriteMany (RWX): Many nodes read-write"
echo "      - Used by: NFS, Ceph, GlusterFS, some cloud storage"
echo "      - Allows: Multiple pods across nodes (read-write)"
echo ""
echo "    - ReadWriteOncePod (RWOP): Single pod read-write"
echo "      - Kubernetes 1.22+"
echo "      - Allows: Only one pod (regardless of node)"
echo ""
echo "  For LLM serving:"
echo "    - Model checkpoints: RWO or RWX"
echo "    - Training data: RWX if distributed training"
echo "    - Model serving: RWO (single model server)"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ PVC requests storage from cluster"
echo "  ✓ Data persists beyond pod lifetime"
echo "  ✓ PVC can be bound to different pods over time"
echo "  ✓ Storage is independent of pod lifecycle"
echo ""
echo "Why this matters for LLM serving:"
echo "  - Store model checkpoints across training runs"
echo "  - Store large model weights on persistent storage"
echo "  - Share training data between distributed training jobs"
echo "  - Persist vector database data"
echo ""
echo "Deployment and PVC are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 02-persistent-volume-claim.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-storage.sh"
echo ""
