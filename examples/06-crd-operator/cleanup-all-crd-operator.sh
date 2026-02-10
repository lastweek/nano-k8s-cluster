#!/bin/bash
# Cleanup script for all CRD and Operator examples
#
# Removes all resources created by CRD and Operator examples.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
NC='\033[0m'           # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${INFO}==========================================${NC}"
echo -e "${INFO}Cleaning Up All CRD and Operator Examples${NC}"
echo -e "${INFO}==========================================${NC}"
echo ""

# Delete operator first (stops reconciliation)
echo -e "${INFO}Deleting operator...${NC}"
kubectl delete -f 02-simple-operator.yaml --ignore-not-found=true > /dev/null 2>&1 || true
echo ""

# Wait for operator to stop
echo -e "${INFO}Waiting for operator to stop...${NC}"
sleep 3

# Delete CRD (also deletes all LLMModel instances)
echo -e "${INFO}Deleting CRD and all instances...${NC}"
kubectl delete -f 01-what-is-crd.yaml --ignore-not-found=true > /dev/null 2>&1 || true
echo ""

# Clean up any orphaned resources
echo -e "${INFO}Cleaning up orphaned resources...${NC}"
kubectl delete deployment -l app=llm-operator --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete pods -l app=llm-operator --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete serviceaccount llm-operator --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete role llm-operator --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete rolebinding llm-operator --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete deployment -l app=llm-serving --ignore-not-found=true > /dev/null 2>&1 || true
kubectl delete pods -l llmmodel --ignore-not-found=true > /dev/null 2>&1 || true

echo -e "${SUCCESS}   ✓ Orphaned resources cleaned up${NC}"
echo ""

# Wait for resources to be fully deleted
echo -e "${INFO}Waiting for resources to be fully deleted...${NC}"
sleep 5

# Verify cleanup
echo -e "${INFO}Verifying cleanup...${NC}"
REMAINING_CRD=$(kubectl get crd llmmodels.ai.example.com --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [ "$REMAINING_CRD" -eq 0 ]; then
    echo -e "${SUCCESS}   ✓ All CRD and Operator resources cleaned up${NC}"
else
    echo -e "${WARN}   ! Some resources may still exist${NC}"
    echo ""
    echo "Remaining CRD:"
    kubectl get crd llmmodels.ai.example.com 2>/dev/null || true
fi

echo ""
echo -e "${SUCCESS}==========================================${NC}"
echo -e "${SUCCESS}Cleanup Complete!${NC}"
echo -e "${SUCCESS}==========================================${NC}"
echo ""
