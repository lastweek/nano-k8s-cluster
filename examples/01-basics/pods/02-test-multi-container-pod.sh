#!/bin/bash
# Test script for 02-multi-container-pod.yaml
#
# This script demonstrates a multi-container pod with sidecar pattern.

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
echo -e "${INFO}Script: test-multi-container-pod.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Multi-Container Pod"
echo "==================================="
echo ""

# Apply the pod
echo -e "${INFO}1. Creating multi-container pod...${NC}"
echo -e "${CMD}$ kubectl apply -f 02-multi-container-pod.yaml${NC}"
kubectl apply -f 02-multi-container-pod.yaml
echo ""

# Wait for pod to be ready
echo -e "${INFO}2. Waiting for pod to be ready...${NC}"
echo -e "${CMD}$ kubectl wait --for=condition=ready pod/multi-container-pod --timeout=60s${NC}"
kubectl wait --for=condition=ready pod/multi-container-pod --timeout=60s
echo ""

# Show pod status with container info
echo -e "${INFO}3. Pod status:${NC}"
echo -e "${CMD}$ kubectl get pods multi-container-pod${NC}"
kubectl get pods multi-container-pod
echo ""

# Show all containers in the pod
echo -e "${INFO}4. Containers in this pod:${NC}"
echo -e "${CMD}$ kubectl get pod multi-container-pod -o jsonpath='{.spec.containers[*].name}'${NC}"
kubectl get pod multi-container-pod -o jsonpath='{.spec.containers[*].name}'
echo ""
echo ""

# Show main container logs
echo -e "${INFO}5. Main container (main-app) logs:${NC}"
echo -e "${CMD}$ kubectl logs multi-container-pod -c main-app --tail=10${NC}"
kubectl logs multi-container-pod -c main-app --tail=10
echo ""

# Show sidecar container logs
echo -e "${INFO}6. Sidecar container logs:${NC}"
echo -e "${CMD}$ kubectl logs multi-container-pod -c sidecar --tail=10${NC}"
kubectl logs multi-container-pod -c sidecar --tail=10
echo ""

# Show both containers are sharing the same network namespace
echo -e "${INFO}7. Verifying shared network namespace:${NC}"
echo "   Main app can reach sidecar via localhost:"
echo -e "${CMD}$ kubectl exec multi-container-pod -c main-app -- ps aux | grep -E '(CONTAINER|nginx|sidecar)'${NC}"
kubectl exec multi-container-pod -c main-app -- ps aux | grep -E "(CONTAINER|nginx|sidecar)" || true
echo ""

echo "==================================="
echo -e "${SUCCESS}Test complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ Multiple containers in same pod"
echo "  ✓ Shared network namespace (localhost)"
echo "  ✓ Shared storage volume (logs)"
echo "  ✓ Sidecar pattern (monitoring)"
echo ""
echo "Pod is still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 02-multi-container-pod.yaml${NC}"
echo ""
