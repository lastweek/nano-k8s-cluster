#!/bin/bash
# Test script for 03-pod-with-resources.yaml
#
# This script demonstrates resource requests and limits.

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
echo -e "${INFO}Script: test-pod-with-resources.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Pod with Resource Limits"
echo "==================================="
echo ""

# Apply the pod
echo -e "${INFO}1. Creating pod with resource constraints...${NC}"
echo -e "${CMD}$ kubectl apply -f 03-pod-with-resources.yaml${NC}"
kubectl apply -f 03-pod-with-resources.yaml
echo ""

# Wait for pod to be ready
echo -e "${INFO}2. Waiting for pod to be ready...${NC}"
echo -e "${CMD}$ kubectl wait --for=condition=ready pod/pod-with-resources --timeout=60s${NC}"
kubectl wait --for=condition=ready pod/pod-with-resources --timeout=60s
echo ""

# Show pod status
echo -e "${INFO}3. Pod status:${NC}"
echo -e "${CMD}$ kubectl get pods pod-with-resources${NC}"
kubectl get pods pod-with-resources
echo ""

# Show resource allocation
echo -e "${INFO}4. Resource allocation:${NC}"
echo -e "${CMD}$ kubectl describe pod pod-with-resources | grep -A 10 'Limits\|Requests'${NC}"
kubectl describe pod pod-with-resources | grep -A 10 "Limits\|Requests"
echo ""

# Show QoS class
echo -e "${INFO}5. QoS (Quality of Service) class:${NC}"
echo -e "${CMD}$ kubectl get pod pod-with-resources -o jsonpath='{.status.qosClass}'${NC}"
kubectl get pod pod-with-resources -o jsonpath='{.status.qosClass}'
echo ""
echo "  QoS Class: Guaranteed (requests == limits)"
echo ""

# Explain the difference
echo -e "${INFO}6. Resource values explained:${NC}"
echo -e "${CMD}$ kubectl get pod pod-with-resources -o jsonpath='{.spec.containers[0].resources}' | jq .${NC}"
kubectl get pod pod-with-resources -o jsonpath='{.spec.containers[0].resources}' | jq .
echo ""
echo "  CPU requests: Used for scheduling decisions"
echo "  CPU limits: Maximum CPU the container can use"
echo "  Memory requests: Guaranteed memory allocation"
echo "  Memory limits: Maximum memory (enforced via OOM)"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ Resource requests (guaranteed for scheduling)"
echo "  ✓ Resource limits (maximum allowed usage)"
echo "  ✓ QoS class (Guaranteed when requests == limits)"
echo ""
echo "Pod is still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 03-pod-with-resources.yaml${NC}"
echo ""
