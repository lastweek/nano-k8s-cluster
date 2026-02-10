#!/bin/bash
# Cleanup script for all service examples
#
# Removes all resources created by service examples.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
NC='\033[0m'           # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${INFO}=======================================${NC}"
echo -e "${INFO}Cleaning Up All Service Examples${NC}"
echo -e "${INFO}=======================================${NC}"
echo ""

# Array of YAML files to delete
YAML_FILES=(
    "01-clusterip.yaml"
    "02-nodeport.yaml"
    "03-service-discovery.yaml"
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
kubectl delete deployments -l service-type=clusterip --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete deployments -l service-type=nodeport --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete deployments -l app=frontend --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete deployments -l app=backend --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete services -l service-type=clusterip --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete services -l service-type=nodeport --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete services -l app=frontend --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete services -l app=backend --ignore-not-found=true > /dev/null 2>&1 || true

echo -e "${SUCCESS}   ✓ Orphaned resources cleaned up${NC}"
echo ""

# Clean up test namespace if it exists
kubectl delete namespace test-dns --ignore-not-found=true > /dev/null 2>&1 || true

# Wait for resources to be fully deleted
echo -e "${INFO}Waiting for resources to be fully deleted...${NC}"
sleep 3

# Verify cleanup
echo -e "${INFO}Verifying cleanup...${NC}"
REMAINING_PODS=$(kubectl get pods -l service-type=clusterip,service-type=nodeport,app=frontend,app=backend --no-headers 2>/dev/null | wc -l | tr -d ' ')
REMAINING_SVC=$(kubectl get services -l service-type=clusterip,service-type=nodeport,app=frontend,app=backend --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [ "$REMAINING_PODS" -eq 0 ] && [ "$REMAINING_SVC" -eq 0 ]; then
    echo -e "${SUCCESS}   ✓ All service resources cleaned up${NC}"
else
    echo -e "${WARN}   ! Some resources may still exist${NC}"
    echo ""
    echo "Remaining resources:"
    kubectl get pods -l service-type=clusterip,service-type=nodeport,app=frontend,app=backend 2>/dev/null || true
    kubectl get services -l service-type=clusterid,service-type=nodeport,app=frontend,app=backend 2>/dev/null || true
fi

echo ""
echo -e "${SUCCESS}=======================================${NC}"
echo -e "${SUCCESS}Cleanup Complete!${NC}"
echo -e "${SUCCESS}=======================================${NC}"
echo ""
