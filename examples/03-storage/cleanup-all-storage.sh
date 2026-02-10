#!/bin/bash
# Cleanup script for all storage examples
#
# Removes all resources created by storage examples.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
NC='\033[0m'           # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${INFO}======================================${NC}"
echo -e "${INFO}Cleaning Up All Storage Examples${NC}"
echo -e "${INFO}======================================${NC}"
echo ""

# Array of YAML files to delete
YAML_FILES=(
    "01-emptydir.yaml"
    "02-persistent-volume-claim.yaml"
    "03-storage-class.yaml"
)

# Delete each YAML file
for yaml in "${YAML_FILES[@]}"; do
    if [ -f "$yaml" ]; then
        echo -e "${INFO}Deleting $yaml...${NC}"
        echo -e "${CMD}$ kubectl delete -f $yaml --ignore-not-found=true${NC}"
        kubectl delete -f "$yaml" --ignore-not-found=true
        echo ""
    fi
done

# Clean up any orphaned resources
echo -e "${INFO}Cleaning up orphaned resources...${NC}"
kubectl delete pods -l app=emptydir-demo --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete pods -l app=model-server --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete pods -l app=storage-demo --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete deployments -l app=model-server --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete pvc -l app=model-storage --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete pvc -l app=storage-demo --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete pv -l app=storage-demo --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete storageclass -l app=storage-demo --ignore-not-found=true > /dev/null 2>&1 || true

echo -e "${SUCCESS}   ✓ Orphaned resources cleaned up${NC}"
echo ""

# Wait for resources to be fully deleted
echo -e "${INFO}Waiting for resources to be fully deleted...${NC}"
sleep 3

# Verify cleanup
echo -e "${INFO}Verifying cleanup...${NC}"
REMAINING_PODS=$(kubectl get pods -l app=emptydir-demo,app=model-server,app=storage-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
REMAINING_PVC=$(kubectl get pvc -l app=model-storage,app=storage-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [ "$REMAINING_PODS" -eq 0 ] && [ "$REMAINING_PVC" -eq 0 ]; then
    echo -e "${SUCCESS}   ✓ All storage resources cleaned up${NC}"
else
    echo -e "${WARN}   ! Some resources may still exist${NC}"
    echo ""
    echo "Remaining resources:"
    kubectl get pods -l app=emptydir-demo,app=model-server,app=storage-demo 2>/dev/null || true
    kubectl get pvc -l app=model-storage,app=storage-demo 2>/dev/null || true
fi

# Check for remaining PVs
REMAINING_PV=$(kubectl get pv -l app=storage-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING_PV" -gt 0 ]; then
    echo ""
    echo -e "${WARN}Warning: PersistentVolumes still exist${NC}"
    echo "These may need manual cleanup:"
    kubectl get pv -l app=storage-demo
    echo ""
    echo "To manually delete PVs:"
    echo "  kubectl delete pv <pv-name>"
fi

echo ""
echo -e "${SUCCESS}======================================${NC}"
echo -e "${SUCCESS}Cleanup Complete!${NC}"
echo -e "${SUCCESS}======================================${NC}"
echo ""
