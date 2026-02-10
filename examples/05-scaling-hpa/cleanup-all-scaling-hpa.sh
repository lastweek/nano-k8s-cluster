#!/bin/bash
# Cleanup script for all HPA examples
#
# Removes all resources created by HPA examples.

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
echo -e "${INFO}Cleaning Up All HPA Examples${NC}"
echo -e "${INFO}======================================${NC}"
echo ""

# Array of YAML files to delete
YAML_FILES=(
    "01-hpa-basic.yaml"
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
kubectl delete deployment -l app=nginx-hpa --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete service -l app=nginx-hpa --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete hpa -l app=nginx-hpa --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete pod load-generator --ignore-not-found=true > /dev/null 2>&1 || true

echo -e "${SUCCESS}   ✓ Orphaned resources cleaned up${NC}"
echo ""

# Wait for resources to be fully deleted
echo -e "${INFO}Waiting for resources to be fully deleted...${NC}"
sleep 3

# Verify cleanup
echo -e "${INFO}Verifying cleanup...${NC}"
REMAINING_DEPLOY=$(kubectl get deployment -l app=nginx-hpa --no-headers 2>/dev/null | wc -l | tr -d ' ')
REMAINING_HPA=$(kubectl get hpa -l app=nginx-hpa --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [ "$REMAINING_DEPLOY" -eq 0 ] && [ "$REMAINING_HPA" -eq 0 ]; then
    echo -e "${SUCCESS}   ✓ All HPA resources cleaned up${NC}"
else
    echo -e "${WARN}   ! Some resources may still exist${NC}"
    echo ""
    echo "Remaining resources:"
    kubectl get deployment -l app=nginx-hpa 2>/dev/null || true
    kubectl get hpa -l app=nginx-hpa 2>/dev/null || true
fi

echo ""
echo -e "${SUCCESS}======================================${NC}"
echo -e "${SUCCESS}Cleanup Complete!${NC}"
echo -e "${SUCCESS}======================================${NC}"
echo ""
