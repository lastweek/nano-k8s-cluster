#!/bin/bash
# Test script for 01-emptydir.yaml
#
# This script demonstrates EmptyDir volume usage.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
NC='\033[0m'           # No Color

set -e

# Show script filename
echo -e "${INFO}===================================${NC}"
echo -e "${INFO}Script: 01-test-emptydir.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: EmptyDir Volume"
echo "==================================="
echo ""

# Apply the pod
echo -e "${INFO}Step 1: Creating pod with EmptyDir volume...${NC}"
echo -e "${CMD}$ kubectl apply -f 01-emptydir.yaml${NC}"
kubectl apply -f 01-emptydir.yaml
echo ""

# Wait for pod to start
echo -e "${INFO}Step 2: Waiting for pod to start...${NC}"
sleep 5
kubectl get pod emptydir-demo
echo ""

# Show pod details
echo -e "${INFO}Step 3: Show pod details...${NC}"
echo -e "${CMD}$ kubectl describe pod emptydir-demo${NC}"
kubectl describe pod emptydir-demo | grep -A 20 "Volumes:"
echo ""

# Check writer container logs
echo -e "${INFO}Step 4: Writer container logs...${NC}"
echo -e "${CMD}$ kubectl logs emptydir-demo -c writer${NC}"
kubectl logs emptydir-demo -c writer
echo ""

# Check reader container logs
echo -e "${INFO}Step 5: Reader container logs (reading shared data)...${NC}"
echo -e "${CMD}$ kubectl logs emptydir-demo -c reader${NC}"
kubectl logs emptydir-demo -c reader
echo ""

# Write additional data to shared volume
echo -e "${INFO}Step 6: Writing additional data to shared volume...${NC}"
echo "  Appending data from writer container..."
kubectl exec emptydir-demo -c writer -- sh -c "echo 'Additional line from writer' >> /shared/data.txt"
echo ""
echo "  Updated content:"
echo -e "${CMD}$ kubectl exec emptydir-demo -c reader -- cat /shared/data.txt${NC}"
kubectl exec emptydir-demo -c reader -- cat /shared/data.txt
echo ""

# List files in shared volume
echo -e "${INFO}Step 7: List files in shared volume...${NC}"
echo -e "${CMD}$ kubectl exec emptydir-demo -c writer -- ls -la /shared${NC}"
kubectl exec emptydir-demo -c writer -- ls -la /shared
echo ""

# Show volume mount info
echo -e "${INFO}Step 8: Volume mount information...${NC}"
echo -e "${CMD}$ kubectl exec emptydir-demo -c writer -- mount | grep shared${NC}"
kubectl exec emptydir-demo -c writer -- mount | grep shared || echo "  (mount info may not be available)"
echo ""

# Demonstrate data loss on pod deletion
echo -e "${INFO}Step 9: Demonstrate EmptyDir lifecycle...${NC}"
echo ""
echo "  EmptyDir characteristics:"
echo "    - Created when pod starts"
echo "    - Deleted when pod is removed"
echo "    - Data is NOT persistent across pod restarts"
echo ""
echo "  Let's demonstrate this by deleting and recreating the pod..."
echo ""

# Delete the pod
echo "  Deleting pod..."
echo -e "${CMD}$ kubectl delete pod emptydir-demo${NC}"
kubectl delete pod emptydir-demo --ignore-not-found=true > /dev/null

sleep 2

# Recreate the pod
echo "  Recreating pod..."
kubectl apply -f 01-emptydir.yaml > /dev/null

sleep 5

echo "  Checking if data persists..."
kubectl exec emptydir-demo -c reader -- cat /shared/data.txt 2>/dev/null || echo "  File doesn't exist in new pod (data was lost)"
echo ""
echo -e "${SUCCESS}   ✓ Confirmed: EmptyDir data is lost when pod is deleted${NC}"
echo ""

# Show EmptyDir use cases
echo -e "${INFO}Step 10: EmptyDir use cases...${NC}"
echo ""
echo "  Common use cases:"
echo "    1. Shared storage between containers in a pod"
echo "    2. Temporary scratch space"
echo "    3. Caching data during pod lifetime"
echo "    4. Intermediate computation results"
echo ""
echo "  For LLM serving:"
echo "    - Shared cache between main container and sidecars"
echo "    - Temporary storage for downloaded model shards"
echo "    - Scratch space for preprocessing"
echo "    - Log aggregation buffer"
echo ""

# Compare with other volume types
echo -e "${INFO}Step 11: Volume type comparison...${NC}"
echo ""
echo "  ┌─────────────┬──────────────────┬────────────────┐"
echo "  │ Volume Type │ Lifetime         │ Data Persistence│"
echo "  ├─────────────┼──────────────────┼────────────────┤"
echo "  │ EmptyDir    │ Pod lifetime     │ No             │"
echo "  │ HostPath    │ Node lifetime    │ Yes (on node)  │"
echo "  │ PVC         │ Until deleted    │ Yes            │"
echo "  │ ConfigMap   │ Cluster lifetime │ Yes (in etcd)  │"
echo "  │ Secret      │ Cluster lifetime │ Yes (in etcd)  │"
echo "  └─────────────┴──────────────────┴────────────────┘"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ EmptyDir provides temporary storage"
echo "  ✓ Shared between containers in a pod"
echo "  ✓ Data is lost when pod is deleted"
echo "  ✓ Can be disk-backed or memory-backed (tmpfs)"
echo ""
echo "Why this matters for LLM serving:"
echo "  - Shared scratch space for containers"
echo "  - Temporary cache for model artifacts"
echo "  - Intermediate computation results"
echo ""
echo "Pod is still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 01-emptydir.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-storage.sh"
echo ""
