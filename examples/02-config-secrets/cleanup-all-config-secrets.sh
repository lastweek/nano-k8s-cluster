#!/bin/bash
# Cleanup script for all ConfigMap and Secret examples
#
# Removes all resources created by ConfigMap and Secret examples.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
NC='\033[0m'           # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${INFO}============================================${NC}"
echo -e "${INFO}Cleaning Up All ConfigMap and Secret Examples${NC}"
echo -e "${INFO}============================================${NC}"
echo ""

# Array of YAML files to delete
YAML_FILES=(
    "01-configmap.yaml"
    "02-configmap-from-file.yaml"
    "03-secret.yaml"
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
kubectl delete pods -l app=configmap-demo --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete pods -l app=configmap-volume --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete pods -l app=secret-demo --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete configmap -l app=llm-serving --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete configmap -l app=configmap-volume --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete secret -l app=llm-serving --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete secret -l app=secret-demo --ignore-not-found=true > /dev/null 2>&1 || true

echo -e "${SUCCESS}   ✓ Orphaned resources cleaned up${NC}"
echo ""

# Wait for resources to be fully deleted
echo -e "${INFO}Waiting for resources to be fully deleted...${NC}"
sleep 3

# Verify cleanup
echo -e "${INFO}Verifying cleanup...${NC}"
REMAINING_CM=$(kubectl get configmap -l app=llm-serving,app=configmap-volume --no-headers 2>/dev/null | wc -l | tr -d ' ')
REMAINING_SECRET=$(kubectl get secret -l app=llm-serving,app=secret-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [ "$REMAINING_CM" -eq 0 ] && [ "$REMAINING_SECRET" -eq 0 ]; then
    echo -e "${SUCCESS}   ✓ All ConfigMaps and Secrets cleaned up${NC}"
else
    echo -e "${WARN}   ! Some resources may still exist${NC}"
    echo ""
    echo "Remaining ConfigMaps:"
    kubectl get configmap -l app=llm-serving,app=configmap-volume 2>/dev/null || true
    echo ""
    echo "Remaining Secrets:"
    kubectl get secret -l app=llm-serving,app=secret-demo 2>/dev/null || true
fi

echo ""
echo -e "${SUCCESS}============================================${NC}"
echo -e "${SUCCESS}Cleanup Complete!${NC}"
echo -e "${SUCCESS}============================================${NC}"
echo ""
