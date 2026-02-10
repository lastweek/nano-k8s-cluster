#!/bin/bash
# Test script for 02-scaling.yaml
#
# This script demonstrates scaling deployments.

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
echo -e "${INFO}Script: 02-test-scaling.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Deployment Scaling"
echo "==================================="
echo ""

# Apply the deployment
echo -e "${INFO}Step 1: Creating deployment with 3 replicas...${NC}"
echo -e "${CMD}$ kubectl apply -f 02-scaling.yaml${NC}"
kubectl apply -f 02-scaling.yaml
echo ""

# Wait for deployment to be ready
echo -e "${INFO}Step 2: Waiting for deployment to be ready...${NC}"
kubectl rollout status deployment/nginx-scaling --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ Deployment is ready${NC}"
echo ""

# Show initial state
echo -e "${INFO}Step 3: Initial state (3 replicas)...${NC}"
echo -e "${CMD}$ kubectl get deployment nginx-scaling${NC}"
kubectl get deployment nginx-scaling
echo ""
echo -e "${CMD}$ kubectl get pods -l app=nginx${NC}"
kubectl get pods -l app=nginx
echo ""

# Scale up
echo -e "${INFO}Step 4: Scaling up to 5 replicas...${NC}"
echo -e "${CMD}$ kubectl scale deployment nginx-scaling --replicas=5${NC}"
kubectl scale deployment nginx-scaling --replicas=5
echo ""

# Wait for scale up
echo "   Waiting for new pods to be ready..."
kubectl rollout status deployment/nginx-scaling --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ Scaled to 5 replicas${NC}"
echo ""

echo -e "${CMD}$ kubectl get pods -l app=nginx${NC}"
kubectl get pods -l app=nginx
echo ""

# Scale down
echo -e "${INFO}Step 5: Scaling down to 2 replicas...${NC}"
echo -e "${CMD}$ kubectl scale deployment nginx-scaling --replicas=2${NC}"
kubectl scale deployment nginx-scaling --replicas=2
echo ""

# Wait for scale down
echo "   Waiting for pods to terminate..."
kubectl rollout status deployment/nginx-scaling --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ Scaled down to 2 replicas${NC}"
echo ""

echo -e "${CMD}$ kubectl get pods -l app=nginx${NC}"
kubectl get pods -l app=nginx
echo ""

# Show deployment capacity
echo -e "${INFO}Step 6: Deployment capacity info...${NC}"
echo -e "${CMD}$ kubectl get deployment nginx-scaling -o custom-columns='NAME:.metadata.name,REPLICAS:.spec.replicas,AVAILABLE:.status.availableReplicas,UNAVAILABLE:.status.unavailableReplicas'${NC}"
kubectl get deployment nginx-scaling -o custom-columns='NAME:.metadata.name,REPLICAS:.spec.replicas,AVAILABLE:.status.availableReplicas,UNAVAILABLE:.status.unavailableReplicas'
echo ""

# Explain HPA briefly
echo -e "${INFO}Step 7: Autoscaling (HPA)...${NC}"
echo ""
echo "  For production, use Horizontal Pod Autoscaler (HPA):"
echo ""
echo "  ${CMD}kubectl autoscale deployment nginx-scaling --min=2 --max=10 --cpu-percent=80${NC}"
echo ""
echo "  This automatically scales based on CPU usage."
echo "  You'll learn about HPA in later examples."
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ Manual scaling up (3 → 5 replicas)"
echo "  ✓ Manual scaling down (5 → 2 replicas)"
echo "  ✓ Rollout status waits for ready state"
echo "  ✓ Resources defined help scheduler"
echo ""
echo "Pods are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 02-scaling.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-deployments.sh"
echo ""
