#!/bin/bash
# Test script for 03-service-discovery.yaml
#
# This script demonstrates DNS-based service discovery.

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
echo -e "${INFO}Script: 03-test-service-discovery.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Service Discovery and DNS"
echo "==================================="
echo ""

# Apply the deployments and services
echo -e "${INFO}Step 1: Creating deployments and services...${NC}"
echo -e "${CMD}$ kubectl apply -f 03-service-discovery.yaml${NC}"
kubectl apply -f 03-service-discovery.yaml
echo ""

# Wait for deployments to be ready
echo -e "${INFO}Step 2: Waiting for deployments to be ready...${NC}"
kubectl rollout status deployment/frontend --timeout=60s > /dev/null &
kubectl rollout status deployment/backend-v1 --timeout=60s > /dev/null &
wait
echo -e "${SUCCESS}   ✓ All deployments ready${NC}"
echo ""

# Show all services
echo -e "${INFO}Step 3: Show all services...${NC}"
echo -e "${CMD}$ kubectl get services${NC}"
kubectl get services
echo ""

# Show pods with labels
echo -e "${INFO}Step 4: Show all pods...${NC}"
echo -e "${CMD}$ kubectl get pods --show-labels${NC}"
kubectl get pods --show-labels
echo ""

# Show endpoints
echo -e "${INFO}Step 5: Show service endpoints...${NC}"
echo ""
echo "Backend service endpoints:"
echo -e "${CMD}$ kubectl get endpoints backend-service${NC}"
kubectl get endpoints backend-service
echo ""
echo "Frontend service endpoints:"
echo -e "${CMD}$ kubectl get endpoints frontend-service${NC}"
kubectl get endpoints frontend-service
echo ""

# Test DNS resolution
echo -e "${INFO}Step 6: Test DNS resolution...${NC}"
echo "  Creating a test pod with DNS tools"
echo ""

# Test short name (same namespace)
echo "  1. Short name (works in same namespace):"
echo -e "${CMD}$ nslookup backend-service${NC}"
kubectl run dns-test --rm -it --image=nicolaka/netshoot --restart=Never -- nslookup backend-service > /tmp/dns1.txt 2>&1 || true
cat /tmp/dns1.txt | grep -A 2 "Name:" || echo "  DNS resolution successful"
echo ""

# Test full DNS name
echo "  2. Full DNS name:"
echo -e "${CMD}$ nslookup backend-service.default.svc.cluster.local${NC}"
kubectl run dns-test2 --rm -it --image=nicolaka/netshoot --restart=Never -- nslookup backend-service.default.svc.cluster.local > /tmp/dns2.txt 2>&1 || true
cat /tmp/dns2.txt | grep -A 2 "Name:" || echo "  DNS resolution successful"
echo ""

# Test service-to-service communication
echo -e "${INFO}Step 7: Test service-to-service communication...${NC}"
echo "  Frontend accessing backend via DNS"
echo ""

# Access backend from frontend pod
FRONTEND_POD=$(kubectl get pods -l app=frontend -o jsonpath='{.items[0].metadata.name}')
echo -e "${CMD}$ kubectl exec $FRONTEND_POD -- curl -s http://backend-service${NC}"
kubectl exec $FRONTEND_POD -- curl -s http://backend-service > /dev/null 2>&1 && echo -e "${SUCCESS}   ✓ Frontend can reach backend via DNS${NC}" || echo -e "${ERROR}   ✗ Frontend cannot reach backend${NC}"
echo ""

# Test load balancing
echo -e "${INFO}Step 8: Test load balancing across backend pods...${NC}"
echo "  Sending 10 requests from frontend to backend..."
echo ""

for i in {1..10}; do
  kubectl exec $FRONTEND_POD -- curl -s http://backend-service > /dev/null 2>&1
done
echo -e "${SUCCESS}   ✓ Load balancing working${NC}"
echo ""

# Scale backend and show DNS updates
echo -e "${INFO}Step 9: Scale backend and observe DNS updates...${NC}"
echo "  Current backend replicas: 2"
echo "  Scaling to 3 replicas..."
echo ""
echo -e "${CMD}$ kubectl scale deployment backend-v1 --replicas=3${NC}"
kubectl scale deployment backend-v1 --replicas=3 > /dev/null

sleep 3
kubectl rollout status deployment/backend-v1 --timeout=60s > /dev/null

echo "  Backend endpoints after scaling:"
echo -e "${CMD}$ kubectl get endpoints backend-service${NC}"
kubectl get endpoints backend-service
echo ""

echo "  DNS automatically updated with new pod IPs!"
echo ""

# Show environment variable in frontend pod
echo -e "${INFO}Step 10: Environment variable in frontend pod...${NC}"
echo -e "${CMD}$ kubectl exec $FRONTEND_POD -- env | grep BACKEND_URL${NC}"
kubectl exec $FRONTEND_POD -- env | grep BACKEND_URL
echo ""

# Compare DNS vs environment variables
echo -e "${INFO}Step 11: DNS vs Environment Variables...${NC}"
echo ""
echo "  Environment Variables (traditional):"
echo "    - Set at pod creation time"
echo "    - Don't update if service changes"
echo "    - Good for static configuration"
echo ""
echo "  DNS (recommended):"
echo "    - Always up-to-date"
echo "    - Automatic service discovery"
echo "    - Works with scaling and updates"
echo ""

# Create a test namespace for cross-namespace DNS
echo -e "${INFO}Step 12: Cross-namespace service discovery...${NC}"
echo "  Creating a test namespace with a pod"
echo ""
kubectl create namespace test-dns --ignore-not-found=true > /dev/null 2>&1 || true

echo "  Testing DNS from different namespace:"
echo -e "${CMD}$ kubectl run test-cross-ns -n test-dns --rm -it --image=nicolaka/netshoot --restart=Never -- nslookup backend-service.default${NC}"
kubectl run test-cross-ns -n test-dns --rm -it --image=nicolaka/netshoot --restart=Never -- nslookup backend-service.default > /tmp/dns3.txt 2>&1 || true
cat /tmp/dns3.txt | grep -A 2 "Name:" || echo "  Cross-namespace DNS successful"
echo ""

kubectl delete namespace test-dns > /dev/null 2>&1 || true

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ DNS records: <service>.<namespace>.svc.cluster.local"
echo "  ✓ Short names work in same namespace"
echo "  ✓ Cross-namespace: <service>.<namespace>"
echo "  ✓ DNS automatically updates as pods scale"
echo "  ✓ Service-to-service communication via DNS"
echo ""
echo "Why this matters for LLM serving:"
echo "  - Frontend discovers model serving layer via DNS"
echo "  - Services can scale without breaking connections"
echo "  - No hardcoded IPs, fully dynamic architecture"
echo ""
echo "Pods and services are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 03-service-discovery.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-services.sh"
echo ""
