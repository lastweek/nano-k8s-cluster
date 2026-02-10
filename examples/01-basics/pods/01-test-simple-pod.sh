#!/bin/bash
# Test script for 01-simple-pod.yaml
#
# This script demonstrates a basic single-container pod.

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
echo -e "${INFO}Script: test-simple-pod.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Simple Pod"
echo "==================================="
echo ""

# Apply the pod
echo -e "${INFO}1. Creating pod...${NC}"
echo -e "${CMD}$ kubectl apply -f 01-simple-pod.yaml${NC}"
kubectl apply -f 01-simple-pod.yaml
echo ""

# Wait for pod to be ready
echo -e "${INFO}2. Waiting for pod to be ready...${NC}"
echo -e "${CMD}$ kubectl wait --for=condition=ready pod/simple-pod --timeout=60s${NC}"
kubectl wait --for=condition=ready pod/simple-pod --timeout=60s
echo ""

# Show pod status
echo -e "${INFO}3. Pod status:${NC}"
echo -e "${CMD}$ kubectl get pods simple-pod${NC}"
kubectl get pods simple-pod
echo ""

# Show pod details
echo -e "${INFO}4. Pod details:${NC}"
echo -e "${CMD}$ kubectl describe pod simple-pod | grep -A 5 'Containers:'${NC}"
kubectl describe pod simple-pod | grep -A 5 "Containers:"
echo ""

# Show logs
echo -e "${INFO}5. Container logs:${NC}"
echo -e "${CMD}$ kubectl logs simple-pod${NC}"
kubectl logs simple-pod
echo ""

# Test connectivity (in background)
echo -e "${INFO}6. Testing HTTP endpoint (port forward)...${NC}"
echo "   Starting port forward in background..."
echo -e "${CMD}$ kubectl port-forward simple-pod 8080:80 &${NC}"
kubectl port-forward simple-pod 8080:80 > /dev/null 2>&1 &
PF_PID=$!

# Wait for port forward to start
sleep 2

# Test the endpoint
echo -e "${CMD}$ curl -s http://localhost:8080 | head -5${NC}"
if curl -s http://localhost:8080 > /dev/null; then
    echo -e "${SUCCESS}   ✓ HTTP endpoint is reachable${NC}"
    echo "   Response:"
    curl -s http://localhost:8080 | head -5
else
    echo -e "${ERROR}   ✗ HTTP endpoint is not reachable${NC}"
fi

# Clean up port forward
kill $PF_PID 2>/dev/null || true
echo ""

# Show how to exec into the pod
echo -e "${INFO}7. Exec into the pod:${NC}"
echo ""
echo "   You can get an interactive shell in the pod:"
echo -e "${CMD}   $ kubectl exec -it simple-pod -- sh${NC}"
echo ""
echo "   Inside the pod, try:"
echo "     - ls /"
echo "     - ps aux"
echo "     - cat /etc/os-release"
echo "     - wget -O- localhost"
echo "     - exit"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test complete!${NC}"
echo "==================================="
echo ""
echo "Pod is still running. Try exec'ing into it:"
echo -e "${CMD}$ kubectl exec -it simple-pod -- sh${NC}"
echo ""
echo "To clean up:"
echo -e "${CMD}$ kubectl delete -f 01-simple-pod.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-pods.sh"
echo ""
