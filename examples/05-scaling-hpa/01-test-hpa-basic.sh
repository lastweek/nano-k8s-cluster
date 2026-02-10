#!/bin/bash
# Test script for 01-hpa-basic.yaml
#
# This script demonstrates basic HPA usage.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
WARN='\033[0;35m'      # Magenta for warnings
NC='\033[0m'           # No Color

set -e

# Show script filename
echo -e "${INFO}===================================${NC}"
echo -e "${INFO}Script: 01-test-hpa-basic.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Horizontal Pod Autoscaler (Basic)"
echo "==================================="
echo ""

# Check metrics server
echo -e "${INFO}Step 1: Checking metrics-server...${NC}"
if kubectl get deployment metrics-server -n kube-system > /dev/null 2>&1; then
    echo -e "${SUCCESS}   ✓ metrics-server is installed${NC}"
else
    echo -e "${WARN}   ! metrics-server not found${NC}"
    echo ""
    echo "  Installing metrics-server..."
    echo -e "${CMD}$ kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml${NC}"
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    echo ""
    echo "  Waiting for metrics-server to be ready..."
    kubectl wait --for=condition=available deployment/metrics-server -n kube-system --timeout=120s > /dev/null
    echo -e "${SUCCESS}   ✓ metrics-server ready${NC}"
fi
echo ""

# Apply the deployment, service, and HPA
echo -e "${INFO}Step 2: Creating deployment, service, and HPA...${NC}"
echo -e "${CMD}$ kubectl apply -f 01-hpa-basic.yaml${NC}"
kubectl apply -f 01-hpa-basic.yaml
echo ""

# Wait for deployment to be ready
echo -e "${INFO}Step 3: Waiting for deployment to be ready...${NC}"
kubectl rollout status deployment/nginx-hpa --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ Deployment ready${NC}"
echo ""

# Show initial pods
echo -e "${INFO}Step 4: Show initial pods...${NC}"
echo -e "${CMD}$ kubectl get pods -l app=nginx-hpa${NC}"
kubectl get pods -l app=nginx-hpa
echo ""

# Show HPA
echo -e "${INFO}Step 5: Show HPA status...${NC}"
echo -e "${CMD}$ kubectl get hpa nginx-hpa${NC}"
kubectl get hpa nginx-hpa
echo ""

# Show HPA details
echo -e "${INFO}Step 6: Show HPA details...${NC}"
echo -e "${CMD}$ kubectl describe hpa nginx-hpa${NC}"
kubectl describe hpa nginx-hpa
echo ""

# Show resource usage
echo -e "${INFO}Step 7: Show current resource usage...${NC}"
echo -e "${CMD}$ kubectl top pods -l app=nginx-hpa${NC}"
kubectl top pods -l app=nginx-hpa
echo ""

# Show HPA configuration
echo -e "${INFO}Step 8: HPA configuration...${NC}"
echo "  Min replicas: 2"
echo "  Max replicas: 10"
echo "  Target CPU: 50%"
echo "  Target Memory: 80%"
echo ""
echo "  Current metrics:"
kubectl get hpa nginx-hpa -o jsonpath='{.status.currentMetrics}' | jq . 2>/dev/null || kubectl get hpa nginx-hpa -o jsonpath='{.status.currentMetrics}'
echo ""

# Generate load to trigger scale-up
echo -e "${INFO}Step 9: Generating load to trigger scale-up...${NC}"
echo "  Creating a load generator pod..."
echo ""

# Create a simple load generator
kubectl run load-generator --image=busybox --requests=cpu=100m --restart=Never -i -- sh -c '
  echo "Starting load generation..."
  echo "This will send continuous requests to nginx-hpa-service"
  echo ""
  while true; do
    wget -q -O- http://nginx-hpa-service > /dev/null 2>&1 &
    # Fork multiple requests to increase load
    for i in 1 2 3 4 5; do
      wget -q -O- http://nginx-hpa-service > /dev/null 2>&1 &
    done
    sleep 0.1
  done
' > /dev/null 2>&1 &

LOAD_PID=$!
echo "  Load generator started (PID: $LOAD_PID)"
echo ""

# Wait and watch HPA scale up
echo -e "${INFO}Step 10: Watching HPA scale up (30 seconds)...${NC}"
echo "  Current replicas: $(kubectl get deployment nginx-hpa -o jsonpath='{.spec.replicas}')"
echo ""
for i in {1..6}; do
    REPLICAS=$(kubectl get deployment nginx-hpa -o jsonpath='{.spec.replicas}')
    CPU=$(kubectl get hpa nginx-hpa -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}')
    echo "  [$i/6] Replicas: $REPLICAS, CPU: ${CPU}%"
    sleep 5
done
echo ""

# Show scaled pods
echo -e "${INFO}Step 11: Show scaled pods...${NC}"
echo -e "${CMD}$ kubectl get pods -l app=nginx-hpa${NC}"
kubectl get pods -l app=nginx-hpa
echo ""

# Show HPA status
echo -e "${INFO}Step 12: HPA status after load...${NC}"
echo -e "${CMD}$ kubectl get hpa nginx-hpa${NC}"
kubectl get hpa nginx-hpa
echo ""

# Stop load generator
echo -e "${INFO}Step 13: Stopping load generator...${NC}"
kubectl delete pod load-generator --ignore-not-found=true > /dev/null
kill $LOAD_PID 2>/dev/null || true
echo -e "${SUCCESS}   ✓ Load stopped${NC}"
echo ""

# Watch HPA scale down
echo -e "${INFO}Step 14: Watching HPA scale down (may take a few minutes)...${NC}"
echo "  Stabilization window: 300 seconds (5 minutes)"
echo "  This allows HPA to wait before scaling down"
echo ""
echo "  Current replicas: $(kubectl get deployment nginx-hpa -o jsonpath='{.spec.replicas}')"
echo ""
echo "  Note: Scale down will happen after stabilization window"
echo "  To see scale down immediately, you can:"
echo "    kubectl edit hpa nginx-hpa"
echo "    Change stabilizationWindowSeconds to 0"
echo ""

# Show HPA behavior
echo -e "${INFO}Step 15: HPA behavior configuration...${NC}"
echo -e "${CMD}$ kubectl get hpa nginx-hpa -o jsonpath='{.spec.behavior}' | jq .${NC}"
kubectl get hpa nginx-hpa -o jsonpath='{.spec.behavior}' | jq . 2>/dev/null || kubectl get hpa nginx-hpa -o yaml | grep -A 20 "behavior:"
echo ""

echo "  Scale down policy:"
echo "    - Wait 300 seconds before scaling down"
echo "    - Scale down by max 50% at once"
echo ""
echo "  Scale up policy:"
echo "    - Scale up immediately (no wait)"
echo "    - Can double pod count or add 4 pods (whichever is more)"
echo ""

# Show HPA events
echo -e "${INFO}Step 16: HPA events...${NC}"
echo -e "${CMD}$ kubectl describe hpa nginx-hpa | tail -20${NC}"
kubectl describe hpa nginx-hpa | tail -20
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ HPA automatically scales pods based on CPU/memory"
echo "  ✓ Resource requests are required for HPA"
echo "  ✓ Scale up happens quickly"
echo "  ✓ Scale down has stabilization window"
echo "  ✓ HPA behavior can be customized"
echo ""
echo "Why this matters for LLM serving:"
echo "  - Auto-scale based on request load"
echo "  - Cost optimization: scale down during low traffic"
echo "  - Handle traffic spikes automatically"
echo "  - Can use custom metrics (requests per second, GPU utilization)"
echo ""
echo "Deployment, service, and HPA are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 01-hpa-basic.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-scaling-hpa.sh"
echo ""
