#!/bin/bash
# Cleanup script for all deployment examples
#
# Removes all resources created by the examples in this directory.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
NC='\033[0m'           # No Color

set -e

echo -e "${INFO}===================================${NC}"
echo -e "${INFO}Cleaning Up All Deployment Examples${NC}"
echo -e "${INFO}===================================${NC}"
echo ""

echo -e "${INFO}Deleting all deployments...${NC}"
echo -e "${CMD}$ kubectl delete deployments -l app=nginx --ignore-not-found=true${NC}"
kubectl delete deployments -l app=nginx --ignore-not-found=true

echo ""
echo "Waiting for resources to be deleted..."
kubectl delete pods -l app=nginx --ignore-not-found=true > /dev/null
sleep 3

echo -e "${SUCCESS}✓ Cleanup complete!${NC}"
echo ""

# Show remaining resources (if any)
REMAINING=$(kubectl get all -l app=nginx --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING" -gt 0 ]; then
    echo "Remaining resources with app=nginx label:"
    echo -e "${CMD}$ kubectl get all -l app=nginx${NC}"
    kubectl get all -l app=nginx
else
    echo -e "${SUCCESS}No resources remaining${NC}"
fi
echo ""
