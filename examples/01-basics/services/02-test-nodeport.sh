#!/bin/bash
# Test script for 02-nodeport.yaml
#
# This script demonstrates NodePort service for external access.

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
echo -e "${INFO}Script: 02-test-nodeport.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: NodePort Service (External Access)"
echo "==================================="
echo ""

# Apply the deployment and service
echo -e "${INFO}Step 1: Creating deployment and NodePort service...${NC}"
echo -e "${CMD}$ kubectl apply -f 02-nodeport.yaml${NC}"
kubectl apply -f 02-nodeport.yaml
echo ""

# Wait for deployment to be ready
echo -e "${INFO}Step 2: Waiting for deployment to be ready...${NC}"
kubectl rollout status deployment/nginx-nodeport --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ Deployment ready (2 pods)${NC}"
echo ""

# Show service
echo -e "${INFO}Step 3: Show service...${NC}"
echo -e "${CMD}$ kubectl get service nginx-nodeport${NC}"
kubectl get service nginx-nodeport
echo ""

# Get node port
echo -e "${INFO}Step 4: Get NodePort...${NC}"
NODE_PORT=$(kubectl get service nginx-nodeport -o jsonpath='{.spec.ports[0].nodePort}')
echo -e "${CMD}$ kubectl get service nginx-nodeport -o jsonpath='{.spec.ports[0].nodePort}'${NC}"
echo -e "${SUCCESS}NodePort: $NODE_PORT${NC}"
echo ""

# Get ClusterIP (NodePort also has one)
echo -e "${INFO}Step 5: Get ClusterIP (NodePort also creates ClusterIP)...${NC}"
CLUSTER_IP=$(kubectl get service nginx-nodeport -o jsonpath='{.spec.clusterIP}')
echo -e "${CMD}$ kubectl get service nginx-nodeport -o jsonpath='{.spec.clusterIP}'${NC}"
echo -e "${SUCCESS}ClusterIP: $CLUSTER_IP${NC}"
echo ""

# Get node IP
echo -e "${INFO}Step 6: Get node IP...${NC}"
echo -e "${CMD}$ kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}'${NC}"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo -e "${SUCCESS}Node IP: $NODE_IP${NC}"
echo ""

# Show service details
echo -e "${INFO}Step 7: Service details...${NC}"
echo -e "${CMD}$ kubectl describe service nginx-nodeport${NC}"
kubectl describe service nginx-nodeport
echo ""

# Test from within cluster (ClusterIP still works)
echo -e "${INFO}Step 8: Test ClusterIP from within cluster...${NC}"
kubectl run test-curl --rm -it --image=curlimages/curl --restart=Never -- curl -s http://nginx-nodeport > /dev/null 2>&1 || {
    echo -e "${ERROR}Failed to connect via ClusterIP${NC}"
    exit 1
}
echo -e "${SUCCESS}   ✓ ClusterIP accessible from within cluster${NC}"
echo ""

# For minikube, use minikube service command
echo -e "${INFO}Step 9: For minikube, access via minikube service...${NC}"
echo -e "${CMD}$ minikube service nginx-nodeport --url${NC}"
MINIKUBE_URL=$(minikube service nginx-nodeport --url 2>/dev/null || echo "")
if [ -n "$MINIKUBE_URL" ]; then
    echo -e "${SUCCESS}Minikube URL: $MINIKUBE_URL${NC}"
    echo ""
    echo "  Testing external access..."
    curl -s $MINIKUBE_URL > /dev/null 2>&1 && echo -e "${SUCCESS}   ✓ External access working!${NC}" || echo -e "${WARN}   ✗ External access failed${NC}"
else
    echo "  (Not running on minikube, skipping minikube service test)"
fi
echo ""

# Show port mapping
echo -e "${INFO}Step 10: Port mapping...${NC}"
echo "  External:   NodeIP:$NODE_PORT ->"
echo "  Service:    ClusterIP:$CLUSTER_IP:$NODE_PORT ->"
echo "  Container:  PodIP:80"
echo ""

# Show endpoints
echo -e "${INFO}Step 11: Show endpoints...${NC}"
echo -e "${CMD}$ kubectl get endpoints nginx-nodeport${NC}"
kubectl get endpoints nginx-nodeport
echo ""

# Show all services
echo -e "${INFO}Step 12: Show all services...${NC}"
echo -e "${CMD}$ kubectl get services${NC}"
kubectl get services
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ NodePort: External access via NodeIP:NodePort"
echo "  ✓ NodePort also creates ClusterIP for internal access"
echo "  ✓ Port mapping: NodePort -> Service Port -> Target Port"
echo "  ✓ Works on all nodes (not just where pods run)"
echo ""
echo "Why this matters for LLM serving:"
echo "  - NodePort allows external access during development"
echo "  - Useful for testing model serving from local machine"
echo "  - Production: Use LoadBalancer or Ingress instead"
echo ""
echo "Pods and service are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 02-nodeport.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-services.sh"
echo ""
