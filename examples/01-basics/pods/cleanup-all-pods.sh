#!/bin/bash
# Cleanup script for all pod examples
#
# Removes all pods created by the examples in this directory.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
NC='\033[0m'           # No Color

set -e

echo -e "${INFO}===================================${NC}"
echo -e "${INFO}Cleaning Up All Pod Examples${NC}"
echo -e "${INFO}===================================${NC}"
echo ""

PODS=(
    "01-simple-pod"
    "02-multi-container-pod"
    "03-pod-with-resources"
    "04-pod-with-probes"
    "05-pod-with-env"
    "06-pod-with-init"
)

echo -e "${INFO}Deleting pods...${NC}"
for POD in "${PODS[@]}"; do
    if kubectl get pod "$POD" --ignore-not-found=true &>/dev/null; then
        echo -e "${CMD}$ kubectl delete pod $POD${NC}"
        kubectl delete pod "$POD" --ignore-not-found=true
    else
        echo "  $POD - not found (skipping)"
    fi
done

echo ""
echo "Waiting for pods to be deleted..."
kubectl wait --for=delete pod/01-simple-pod --timeout=30s --ignore-not-found=true &>/dev/null || true
kubectl wait --for=delete pod/02-multi-container-pod --timeout=30s --ignore-not-found=true &>/dev/null || true
kubectl wait --for=delete pod/03-pod-with-resources --timeout=30s --ignore-not-found=true &>/dev/null || true
kubectl wait --for=delete pod/04-pod-with-probes --timeout=30s --ignore-not-found=true &>/dev/null || true
kubectl wait --for=delete pod/05-pod-with-env --timeout=30s --ignore-not-found=true &>/dev/null || true
kubectl wait --for=delete pod/06-pod-with-init --timeout=30s --ignore-not-found=true &>/dev/null || true

echo -e "${SUCCESS}✓ Cleanup complete!${NC}"
echo ""

# Show remaining pods (if any)
REMAINING=$(kubectl get pods -n default --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING" -gt 0 ]; then
    echo "Remaining pods in default namespace:"
    echo -e "${CMD}$ kubectl get pods${NC}"
    kubectl get pods
else
    echo -e "${SUCCESS}No pods remaining in default namespace${NC}"
fi
echo ""
