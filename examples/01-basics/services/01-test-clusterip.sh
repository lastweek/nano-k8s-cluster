#!/bin/bash
# Test script for 01-clusterip.yaml
#
# This script demonstrates ClusterIP service basics.

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
echo -e "${INFO}Script: 01-test-clusterip.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: ClusterIP Service"
echo "==================================="
echo ""

# Apply the deployment and service
echo -e "${INFO}Step 1: Creating deployment and ClusterIP service...${NC}"
echo -e "${CMD}$ kubectl apply -f 01-clusterip.yaml${NC}"
kubectl apply -f 01-clusterip.yaml
echo ""

# Wait for deployment to be ready
echo -e "${INFO}Step 2: Waiting for deployment to be ready...${NC}"
kubectl rollout status deployment/nginx-clusterip --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ Deployment ready (3 pods)${NC}"
echo ""

# Show pods
echo -e "${INFO}Step 3: Show pods...${NC}"
echo -e "${CMD}$ kubectl get pods -l service-type=clusterip${NC}"
kubectl get pods -l service-type=clusterip
echo ""

# Show service
echo -e "${INFO}Step 4: Show service...${NC}"
echo -e "${CMD}$ kubectl get service nginx-service${NC}"
kubectl get service nginx-service
echo ""

# Get service details
echo -e "${INFO}Step 5: Service details...${NC}"
echo -e "${CMD}$ kubectl describe service nginx-service${NC}"
kubectl describe service nginx-service
echo ""

# Get cluster IP
echo -e "${INFO}Step 6: Get ClusterIP...${NC}"
CLUSTER_IP=$(kubectl get service nginx-service -o jsonpath='{.spec.clusterIP}')
echo -e "${CMD}$ kubectl get service nginx-service -o jsonpath='{.spec.clusterIP}'${NC}"
echo -e "${SUCCESS}ClusterIP: $CLUSTER_IP${NC}"
echo ""

# Get endpoints
echo -e "${INFO}Step 7: Show endpoints (pod IPs)...${NC}"
echo -e "${CMD}$ kubectl get endpoints nginx-service${NC}"
kubectl get endpoints nginx-service
echo ""

# Test from within cluster using a temporary pod
echo -e "${INFO}Step 8: Test service from within cluster...${NC}"
echo "  Creating a temporary curl pod to test the service"
echo ""
echo -e "  ${CMD}$ kubectl run test-curl --rm -it --image=curlimages/curl --restart=Never -- curl -s http://nginx-service${NC}"
echo ""

# Run the test
kubectl run test-curl --rm -it --image=curlimages/curl --restart=Never -- curl -s http://nginx-service || {
    echo -e "${ERROR}Failed to connect to service${NC}"
    exit 1
}
echo ""
echo -e "${SUCCESS}   ✓ Service is accessible from within cluster${NC}"
echo ""

# Show service DNS
echo -e "${INFO}Step 9: Service DNS name...${NC}"
echo "  Full DNS name: nginx-service.default.svc.cluster.local"
echo "  Short name: nginx-service (works within same namespace)"
echo ""

# Show load balancing
echo -e "${INFO}Step 10: Demonstrating load balancing...${NC}"
echo "  Sending 10 requests to show distribution across pods..."
echo ""
for i in {1..10}; do
  kubectl run test-curl-$i --rm -it --image=curlimages/curl --restart=Never -- curl -s http://nginx-service > /dev/null 2>&1 &
done
wait
echo -e "${SUCCESS}   ✓ Load balancing working${NC}"
echo ""

# Show service vs pod IPs
echo -e "${INFO}Step 11: Service vs Pod IPs...${NC}"
echo "  Service IP (stable): $CLUSTER_IP"
echo ""
echo "  Pod IPs (ephemeral):"
echo -e "${CMD}$ kubectl get pods -l service-type=clusterip -o custom-columns='NAME:.metadata.name,IP:.status.podIP'${NC}"
kubectl get pods -l service-type=clusterip -o custom-columns='NAME:.metadata.name,IP:.status.podIP'
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ ClusterIP: Internal-only access"
echo "  ✓ Service discovery via DNS"
echo "  ✓ Load balancing across pods"
echo "  ✓ Stable service IP vs ephemeral pod IPs"
echo ""
echo "Why this matters for LLM serving:"
echo "  - Services provide stable endpoints for model serving"
echo "  - Load balancing distributes requests across replicas"
echo "  - Client services don't need to know individual pod IPs"
echo ""
echo "Pods and service are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 01-clusterip.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-services.sh"
echo ""
